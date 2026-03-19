#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Sets up internal demo applications on a Windows Server for the ZPA demo lab.

.DESCRIPTION
    Installs and configures:
      - IIS with a demo landing page (ports 80 and 443)
      - Additional IIS bindings on ports 8080 and 8443
      - A simple "Shadow IT" HTTP listener on port 9090 (for policy-block demo)
      - Verifies RDP is enabled
      - Creates an SMB share named LabShare

.NOTES
    Run as Administrator on Windows Server 2022.
    Script is idempotent – safe to run multiple times.
#>

param(
    [string]$ServerIP    = "192.168.1.20",
    [string]$SharePath   = "C:\LabShare",
    [string]$WebRootPath = "C:\inetpub\wwwroot"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ── Helper functions ──────────────────────────────────────────────────────────
function Write-Step   { param([string]$msg) Write-Host "`n[STEP]  $msg" -ForegroundColor Cyan }
function Write-OK     { param([string]$msg) Write-Host "[OK]    $msg" -ForegroundColor Green }
function Write-Warn   { param([string]$msg) Write-Host "[WARN]  $msg" -ForegroundColor Yellow }

# ── 1. Install IIS ────────────────────────────────────────────────────────────
Write-Step "Installing IIS and management tools..."
$features = @(
    "Web-Server",
    "Web-Common-Http",
    "Web-Static-Content",
    "Web-Default-Doc",
    "Web-Mgmt-Console",
    "Web-Scripting-Tools"
)
$result = Install-WindowsFeature -Name $features -IncludeManagementTools
if ($result.Success) {
    Write-OK "IIS installed (restart required: $($result.RestartNeeded))"
} else {
    Write-Warn "IIS installation may have partial failures. Continuing..."
}

Import-Module WebAdministration -ErrorAction SilentlyContinue

# ── 2. Create demo landing page ───────────────────────────────────────────────
Write-Step "Creating IIS demo landing page..."
$indexPath = Join-Path $WebRootPath "index.html"
$html = @"
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>ZPA Demo – Internal App Portal</title>
  <style>
    body { font-family: Arial, sans-serif; background:#f4f6f9; margin:0; padding:40px; }
    .card { background:#fff; border-radius:8px; padding:30px; max-width:600px;
            margin:40px auto; box-shadow:0 2px 8px rgba(0,0,0,.15); }
    h1   { color:#005eb8; }
    .badge { display:inline-block; background:#00b388; color:#fff;
             border-radius:4px; padding:3px 10px; font-size:.85em; }
  </style>
</head>
<body>
  <div class="card">
    <h1>&#x1F512; ZPA Demo – Internal App Portal</h1>
    <p><span class="badge">PRIVATE</span> You are accessing this app through
    Zscaler Private Access.</p>
    <p>This page is only reachable if you have an active ZPA session with
    the correct access policy.</p>
    <hr>
    <h2>Available Demo Apps</h2>
    <ul>
      <li><a href="http://$ServerIP/">HTTP (port 80)</a></li>
      <li><a href="https://$ServerIP/">HTTPS (port 443)</a></li>
      <li><a href="http://$ServerIP:8080/">Alt HTTP (port 8080)</a></li>
      <li><a href="http://$ServerIP:8443/">Alt HTTP (port 8443)</a></li>
    </ul>
  </div>
</body>
</html>
"@
Set-Content -Path $indexPath -Value $html -Encoding UTF8
Write-OK "Landing page written to $indexPath"

# ── 3. IIS bindings ───────────────────────────────────────────────────────────
Write-Step "Configuring IIS bindings..."

function Add-IISBinding {
    param([string]$SiteName, [int]$Port, [string]$Protocol = "http")
    $binding = "${Protocol}/*:${Port}:"
    $existing = Get-WebBinding -Name $SiteName -Protocol $Protocol `
                -Port $Port -ErrorAction SilentlyContinue
    if (-not $existing) {
        New-WebBinding -Name $SiteName -Protocol $Protocol -Port $Port
        Write-OK "Added binding ${Protocol}:${Port} to site '$SiteName'"
    } else {
        Write-OK "Binding ${Protocol}:${Port} already exists on '$SiteName'"
    }
}

# Ensure the Default Web Site is started
Start-WebSite -Name "Default Web Site" -ErrorAction SilentlyContinue
Add-IISBinding -SiteName "Default Web Site" -Port 8080 -Protocol "http"
Add-IISBinding -SiteName "Default Web Site" -Port 8443 -Protocol "http"

# Allow ports 80, 443, 8080, 8443 through Windows Firewall
foreach ($port in @(80, 443, 8080, 8443)) {
    $ruleName = "ZPA-Demo-IIS-TCP-$port"
    if (-not (Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue)) {
        New-NetFirewallRule -DisplayName $ruleName -Direction Inbound `
            -Protocol TCP -LocalPort $port -Action Allow | Out-Null
        Write-OK "Firewall rule added for TCP $port"
    } else {
        Write-OK "Firewall rule for TCP $port already exists"
    }
}

# ── 4. Shadow IT listener (port 9090) ─────────────────────────────────────────
Write-Step "Starting Shadow IT HTTP listener on port 9090..."
$shadowTaskName = "ZPA-Demo-ShadowApp-9090"

# Remove existing scheduled task if present
Unregister-ScheduledTask -TaskName $shadowTaskName -Confirm:$false -ErrorAction SilentlyContinue

$shadowScript = @'
$listener = [System.Net.HttpListener]::new()
$listener.Prefixes.Add("http://+:9090/")
$listener.Start()
while ($listener.IsListening) {
    $ctx = $listener.GetContext()
    $body = [System.Text.Encoding]::UTF8.GetBytes(
        "<html><body><h1>Shadow IT App (port 9090)</h1>" +
        "<p>This app has no ZPA access policy. Access should be blocked.</p>" +
        "</body></html>")
    $ctx.Response.ContentType     = "text/html"
    $ctx.Response.ContentLength64 = $body.Length
    $ctx.Response.OutputStream.Write($body, 0, $body.Length)
    $ctx.Response.OutputStream.Close()
}
'@

$shadowScriptPath = "C:\Windows\Temp\shadow_app.ps1"
Set-Content -Path $shadowScriptPath -Value $shadowScript -Encoding UTF8

$action  = New-ScheduledTaskAction -Execute "powershell.exe" `
             -Argument "-NoProfile -NonInteractive -File `"$shadowScriptPath`""
$trigger = New-ScheduledTaskTrigger -AtStartup
$settings = New-ScheduledTaskSettingsSet `
              -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1)
# Note: ExecutionTimeLimit is not set, so the task runs until stopped manually
# or until the system shuts down. Stop via: Stop-ScheduledTask -TaskName '$shadowTaskName'
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -RunLevel Highest

Register-ScheduledTask -TaskName $shadowTaskName -Action $action `
  -Trigger $trigger -Settings $settings -Principal $principal | Out-Null
Start-ScheduledTask -TaskName $shadowTaskName
Write-OK "Shadow IT listener started on port 9090 via Scheduled Task '$shadowTaskName'"

# Firewall rule for 9090
$ruleName9090 = "ZPA-Demo-ShadowApp-TCP-9090"
if (-not (Get-NetFirewallRule -DisplayName $ruleName9090 -ErrorAction SilentlyContinue)) {
    New-NetFirewallRule -DisplayName $ruleName9090 -Direction Inbound `
        -Protocol TCP -LocalPort 9090 -Action Allow | Out-Null
    Write-OK "Firewall rule added for TCP 9090"
}

# ── 5. Verify RDP ─────────────────────────────────────────────────────────────
Write-Step "Verifying Remote Desktop is enabled..."
$rdpStatus = (Get-ItemProperty `
  "HKLM:\System\CurrentControlSet\Control\Terminal Server" `
  -Name "fDenyTSConnections").fDenyTSConnections

if ($rdpStatus -eq 0) {
    Write-OK "RDP is already enabled."
} else {
    Set-ItemProperty "HKLM:\System\CurrentControlSet\Control\Terminal Server" `
        -Name "fDenyTSConnections" -Value 0
    Write-OK "RDP enabled."
}

$rdpRule = "RemoteDesktop-UserMode-In-TCP"
Enable-NetFirewallRule -Name $rdpRule -ErrorAction SilentlyContinue
Write-OK "RDP firewall rule enabled."

# ── 6. Create SMB share ───────────────────────────────────────────────────────
Write-Step "Creating SMB share 'LabShare'..."
if (-not (Test-Path $SharePath)) {
    New-Item -ItemType Directory -Path $SharePath | Out-Null
    Write-OK "Created folder $SharePath"
}

# Add a demo file so the share is not empty
$demoFile = Join-Path $SharePath "welcome.txt"
if (-not (Test-Path $demoFile)) {
    Set-Content -Path $demoFile -Value @"
Welcome to the ZPA Demo LabShare.

This file share is accessible only through Zscaler Private Access.
If you can read this, your ZPA access policy is working correctly.

Server: $ServerIP
Share:  \\$ServerIP\LabShare
"@
}

if (-not (Get-SmbShare -Name "LabShare" -ErrorAction SilentlyContinue)) {
    New-SmbShare -Name "LabShare" -Path $SharePath `
        -FullAccess "Everyone" -Description "ZPA Demo File Share" | Out-Null
    Write-OK "SMB share 'LabShare' created at $SharePath"
} else {
    Write-OK "SMB share 'LabShare' already exists."
}

$smbRuleName = "ZPA-Demo-SMB-TCP-445"
if (-not (Get-NetFirewallRule -DisplayName $smbRuleName -ErrorAction SilentlyContinue)) {
    New-NetFirewallRule -DisplayName $smbRuleName -Direction Inbound `
        -Protocol TCP -LocalPort 445 -Action Allow | Out-Null
    Write-OK "Firewall rule added for SMB TCP 445"
}

# ── Summary ───────────────────────────────────────────────────────────────────
Write-Host "`n================================================================" -ForegroundColor Cyan
Write-Host " Setup Complete – Internal App Summary" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  HTTP (IIS)         : http://$ServerIP/"
Write-Host "  HTTPS (IIS)        : https://$ServerIP/"
Write-Host "  Alt HTTP           : http://$ServerIP:8080/"
Write-Host "  Alt HTTP           : http://$ServerIP:8443/"
Write-Host "  Shadow IT app      : http://$ServerIP:9090/  (NO ZPA policy!)"
Write-Host "  RDP                : $ServerIP`:3389"
Write-Host "  SMB Share          : \\$ServerIP\LabShare"
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next step: Verify these services appear in ZPA Application Segments."
Write-Host "See docs\Lab_Setup.md for configuration details."
