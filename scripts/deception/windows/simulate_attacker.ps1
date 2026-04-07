#Requires -Version 5.1
<#
.SYNOPSIS
    Zscaler Deception Attacker Simulation — Windows (PowerShell).

.DESCRIPTION
    Simulates a post-breach attacker performing internal reconnaissance,
    credential discovery, and lateral movement on a Windows endpoint.
    Each phase triggers Zscaler Deception alerts on the decoy services and
    tokens deployed by deploy_deception_tokens.ps1 and setup_decoy_services.sh.

    ⚠  WARNING: Run only in authorised lab environments.
       Never execute against production networks or systems you do not own.

    Attack phases:
      Phase 1 – Internal Reconnaissance   (ARP, ping sweep, NetBIOS, DNS)
      Phase 2 – Service Discovery         (TCP port scan, HTTP banner)
      Phase 3 – Credential Discovery      (search for breadcrumb token files)
      Phase 4 – Decoy Interaction         (use fake creds — triggers alerts)
      Phase 5 – Post-Exploitation Probes  (cloud token, Credential Manager)

.PARAMETER TargetHost
    Primary target IP to scan and interact with (default: 192.168.1.10).

.PARAMETER Subnet
    Target subnet for the ping sweep (default: 192.168.1).

.PARAMETER Phase
    Run only a single phase (1–5). Omit to run all phases.

.PARAMETER NoPause
    Skip the "Press Enter to continue" prompts between phases.

.PARAMETER Speed
    Seconds to pause between individual steps (default: 1).

.EXAMPLE
    .\scripts\deception\windows\simulate_attacker.ps1

.EXAMPLE
    .\scripts\deception\windows\simulate_attacker.ps1 -TargetHost 192.168.1.10 -NoPause

.EXAMPLE
    .\scripts\deception\windows\simulate_attacker.ps1 -Phase 4
#>

[CmdletBinding()]
param(
    [string]$TargetHost = '192.168.1.10',
    [string]$Subnet     = '192.168.1',
    [int]   $Phase      = 0,
    [switch]$NoPause,
    [int]   $Speed      = 1
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'SilentlyContinue'

# ---------------------------------------------------------------------------
# Output helpers
# ---------------------------------------------------------------------------
function Write-Alert  { param($Msg) Write-Host "  [DECEPTION ALERT EXPECTED] $Msg" -ForegroundColor Red }
function Write-Action { param($Msg) Write-Host "  [ATTACKER ACTION]  $Msg" -ForegroundColor Yellow }
function Write-Found  { param($Msg) Write-Host "  [FOUND]            $Msg" -ForegroundColor Green }
function Write-Info   { param($Msg) Write-Host "  [INFO]             $Msg" -ForegroundColor Cyan }
function Write-Dim    { param($Msg) Write-Host "  $Msg" -ForegroundColor DarkGray }
function Write-Phase  {
    param($Num, $Title)
    Write-Host ""
    Write-Host ("  " + "─" * 66) -ForegroundColor Cyan
    Write-Host "  Phase ${Num}: ${Title}" -ForegroundColor Cyan -NoNewline
    Write-Host "" -ForegroundColor Cyan
    Write-Host ("  " + "─" * 66) -ForegroundColor Cyan
    Write-Host ""
}
function Pause-Phase {
    if (-not $NoPause) {
        Write-Host ""
        Write-Host "  ↵  Press Enter to continue to next phase…" -ForegroundColor DarkGray
        $null = Read-Host
    }
    Start-Sleep -Seconds $Speed
}
function Step-Delay { Start-Sleep -Seconds $Speed }

$LogFile = "$env:TEMP\deception_attacker_sim.log"

function Write-Log {
    param($Level, $Msg)
    $ts = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    "[$ts] [$Level] $Msg" | Out-File -Append -FilePath $LogFile -Encoding UTF8
}

# ---------------------------------------------------------------------------
# Port test helper
# ---------------------------------------------------------------------------
function Test-TcpPort {
    param([string]$Host, [int]$Port, [int]$TimeoutMs = 2000)
    try {
        $tcp = New-Object System.Net.Sockets.TcpClient
        $ia  = $tcp.BeginConnect($Host, $Port, $null, $null)
        $ok  = $ia.AsyncWaitHandle.WaitOne($TimeoutMs, $false)
        if ($ok -and -not $tcp.Client.Poll(0, [System.Net.Sockets.SelectMode]::SelectError)) {
            $tcp.EndConnect($ia)
            $tcp.Close()
            return $true
        }
        $tcp.Close()
        return $false
    } catch {
        return $false
    }
}

# ---------------------------------------------------------------------------
# HTTP helper (returns status code and partial body)
# ---------------------------------------------------------------------------
function Invoke-DecoyHttp {
    param([string]$Uri, [hashtable]$FormData = @{}, [string]$Method = 'GET')
    try {
        if ($Method -eq 'POST') {
            $body     = ($FormData.GetEnumerator() | ForEach-Object { "$($_.Key)=$([uri]::EscapeDataString($_.Value))" }) -join '&'
            $response = Invoke-WebRequest -Uri $Uri -Method POST -Body $body `
                            -ContentType 'application/x-www-form-urlencoded' `
                            -TimeoutSec 8 -UseBasicParsing
        } else {
            $response = Invoke-WebRequest -Uri $Uri -TimeoutSec 8 -UseBasicParsing
        }
        return [PSCustomObject]@{ Code = $response.StatusCode; Body = $response.Content.Substring(0, [Math]::Min(200, $response.Content.Length)) }
    } catch {
        return [PSCustomObject]@{ Code = 0; Body = '' }
    }
}

# ---------------------------------------------------------------------------
# Phase 1 – Internal Reconnaissance
# ---------------------------------------------------------------------------
function Invoke-Phase1 {
    Write-Phase 1 "Internal Reconnaissance"

    Write-Action "Dumping ARP cache to identify adjacent hosts…"
    Step-Delay
    $arpOutput = arp -a 2>$null | Select-String '\d+\.\d+\.\d+\.\d+'
    $arpOutput | ForEach-Object { Write-Dim "    $_" }
    Write-Log INFO "ARP dump complete"
    Write-Host ""
    Step-Delay

    Write-Action "Ping sweep of subnet ${Subnet}.0/24 (spot check)…"
    $liveHosts = @()
    $testOctets = 1,10,20,30,40,100,200
    foreach ($octet in $testOctets) {
        $ip = "${Subnet}.${octet}"
        $ping = Test-Connection -ComputerName $ip -Count 1 -Quiet -ErrorAction SilentlyContinue
        if ($ping) {
            Write-Found "${ip}  — ALIVE"
            $liveHosts += $ip
        } else {
            Write-Dim   "${ip}  — no response"
        }
    }
    Write-Log INFO "Ping sweep found $($liveHosts.Count) live hosts"
    Write-Host ""
    Step-Delay

    Write-Action "NetBIOS name lookup for live hosts…"
    foreach ($ip in $liveHosts) {
        try {
            $name = [System.Net.Dns]::GetHostEntry($ip).HostName
        } catch {
            $name = '(no PTR record)'
        }
        Write-Found "${ip}  →  ${name}"
    }

    Write-Info "Phase 1 complete."
    Write-Info "DEMO: Recon is passive — no Deception alerts should have fired yet."
    Write-Log INFO "Phase 1 complete"
}

# ---------------------------------------------------------------------------
# Phase 2 – Service Discovery
# ---------------------------------------------------------------------------
function Invoke-Phase2 {
    Write-Phase 2 "Service Discovery (Port Scan + Banner Grab)"

    Write-Action "TCP port scan against ${TargetHost}…"
    Step-Delay

    $ports   = @(22, 80, 443, 445, 2222, 3306, 3307, 4445, 8080, 8081, 3389, 5432, 6379)
    $openPorts = @()

    foreach ($port in $ports) {
        $open = Test-TcpPort -Host $TargetHost -Port $port
        if ($open) {
            Write-Found "${TargetHost}:${port}  — OPEN"
            $openPorts += $port
        } else {
            Write-Dim   "${TargetHost}:${port}  — closed/filtered"
        }
        Start-Sleep -Milliseconds 300
    }
    Write-Log INFO "Port scan found $($openPorts.Count) open ports on ${TargetHost}"
    Write-Host ""
    Step-Delay

    Write-Action "HTTP title grab on open web ports…"
    foreach ($port in @(80, 8080, 8081)) {
        $r = Invoke-DecoyHttp -Uri "http://${TargetHost}:${port}"
        if ($r.Code -gt 0) {
            $title = if ($r.Body -match '<title>(.*?)</title>') { $Matches[1] } else { '(no title)' }
            Write-Found "HTTP ${TargetHost}:${port}  →  title: ${title}  (HTTP $($r.Code))"
        }
    }

    Write-Info "Phase 2 complete."
    Write-Info "DEMO: Ports 2222, 3307, 4445, 8081 are decoys — indistinguishable from real services."
    Write-Log INFO "Phase 2 complete"
}

# ---------------------------------------------------------------------------
# Phase 3 – Credential Discovery
# ---------------------------------------------------------------------------
function Invoke-Phase3 {
    Write-Phase 3 "Credential & Token Discovery (Deception Lure Access)"

    Write-Action "Searching common credential locations on this Windows machine…"
    Step-Delay

    $searchPaths = @(
        @{ Path = "$env:USERPROFILE\.aws\credentials";               Label = "AWS credentials file" },
        @{ Path = "$env:USERPROFILE\.ssh\config";                    Label = "SSH client config" },
        @{ Path = "$env:USERPROFILE\Documents\Projects\webapp\.env"; Label = "Application .env file" },
        @{ Path = "$env:USERPROFILE\Documents\Backups\db_backup.sql";Label = "Database backup" },
        @{ Path = "$env:USERPROFILE\Downloads\passwords_export.csv"; Label = "Password export CSV" },
        @{ Path = "$env:USERPROFILE\Documents\vault_location.txt";   Label = "KeePass hint file" },
        @{ Path = "$env:APPDATA\Roaming\RDP\Default.rdp";            Label = "Saved RDP connection" }
    )

    foreach ($item in $searchPaths) {
        if (Test-Path $item.Path) {
            Write-Found "$($item.Label)  →  $($item.Path)"
            Write-Log LURE_ACCESS "File accessed: $($item.Path)"
            # Show a few interesting lines
            $interesting = Get-Content $item.Path -ErrorAction SilentlyContinue |
                           Where-Object { $_ -match '(?i)(password|passwd|key|secret|token|host|user|access)' } |
                           Where-Object { $_ -notmatch '^#' } |
                           Select-Object -First 4
            $interesting | ForEach-Object { Write-Dim "    $_" }
        } else {
            Write-Dim "$($item.Label)  —  not found"
        }
        Step-Delay
    }

    Write-Host ""
    Write-Action "Enumerating Windows Credential Manager…"
    Step-Delay
    $credList = cmdkey /list 2>$null
    $credList | ForEach-Object { Write-Dim "    $_" }
    Write-Log LURE_ACCESS "Credential Manager enumerated"

    Write-Host ""
    Write-Alert "Deception lures read — AWS credentials, SSH config, .env, passwords CSV"
    Write-Alert "Credential Manager enumerated — fake SMB entry discovered"
    Write-Info  "DEMO: HIGH severity alerts in portal — credential token access on this endpoint."
    Write-Log INFO "Phase 3 complete"
}

# ---------------------------------------------------------------------------
# Phase 4 – Decoy Interaction
# ---------------------------------------------------------------------------
function Invoke-Phase4 {
    Write-Phase 4 "Decoy Interaction — Using Discovered Fake Credentials"

    $portWeb  = 8081
    $portSsh  = 2222
    $portDb   = 3307
    $portFile = 4445

    # ── 4a: Web portal login ─────────────────────────────────────────────────
    Write-Action "Submitting credentials to fake internal web portal…"
    Write-Info   "Target: http://${TargetHost}:${portWeb}/login"
    Write-Info   "Credentials: admin / Welcome1!fake  (from passwords_export.csv)"
    Step-Delay

    $r = Invoke-DecoyHttp -Uri "http://${TargetHost}:${portWeb}/login" `
         -Method POST -FormData @{ username = 'admin'; password = 'Welcome1!fake' }

    if ($r.Code -gt 0) {
        Write-Found "Web portal responded: HTTP $($r.Code)"
        Write-Alert "CRITICAL — Decoy web portal login: http://${TargetHost}:${portWeb}/login"
        Write-Alert "           Credential submitted: admin / Welcome1!fake"
        Write-Log DECOY_HIT "Web portal: ${TargetHost}:${portWeb} — HTTP $($r.Code)"
    } else {
        Write-Info  "Web portal not responding — ensure setup_decoy_services.sh is running."
    }
    Write-Host ""
    Step-Delay

    # ── 4b: SSH honeypot ─────────────────────────────────────────────────────
    Write-Action "Probing fake SSH server (from SSH config breadcrumb)…"
    Write-Info   "Target: ${TargetHost}:${portSsh}  (User: lab-admin)"
    Step-Delay

    $open = Test-TcpPort -Host $TargetHost -Port $portSsh -TimeoutMs 3000
    if ($open) {
        # Grab the SSH banner via a raw TCP read
        try {
            $tcp    = New-Object System.Net.Sockets.TcpClient
            $null   = $tcp.BeginConnect($TargetHost, $portSsh, $null, $null)
            $null   = (New-Object System.Threading.ManualResetEventSlim).Wait(3000)
            $stream = $tcp.GetStream()
            $buf    = New-Object byte[] 256
            $stream.ReadTimeout = 3000
            $read   = $stream.Read($buf, 0, $buf.Length)
            $banner = [System.Text.Encoding]::ASCII.GetString($buf, 0, $read).Trim()
            $tcp.Close()
        } catch {
            $banner = "(SSH banner received)"
        }
        Write-Found "SSH honeypot banner: $banner"
        Write-Alert "CRITICAL — Decoy SSH server touched: ${TargetHost}:${portSsh}"
        Write-Alert "           Credential: lab-admin (from SSH config token)"
        Write-Log DECOY_HIT "SSH honeypot: ${TargetHost}:${portSsh} — banner: $banner"
    } else {
        Write-Info "SSH decoy not responding — ensure setup_decoy_services.sh is running."
    }
    Write-Host ""
    Step-Delay

    # ── 4c: Database probe ───────────────────────────────────────────────────
    Write-Action "Probing fake MySQL server with .env file credentials…"
    Write-Info   "Target: ${TargetHost}:${portDb}  (User: app_prod_user)"
    Step-Delay

    $open = Test-TcpPort -Host $TargetHost -Port $portDb -TimeoutMs 3000
    if ($open) {
        Write-Found "Database port ${portDb} is OPEN — server is responding"
        Write-Alert "CRITICAL — Decoy database server probed: ${TargetHost}:${portDb}"
        Write-Alert "           Credential: app_prod_user (from .env breadcrumb)"
        Write-Log DECOY_HIT "DB probe: ${TargetHost}:${portDb}"
    } else {
        Write-Info "Database decoy not responding — ensure setup_decoy_services.sh is running."
    }
    Write-Host ""
    Step-Delay

    # ── 4d: SMB / Credential Manager ────────────────────────────────────────
    Write-Action "Attempting SMB connection to share discovered in Credential Manager…"
    Write-Info   "Target: \\${TargetHost}\CorpShare  (CORP\svc-backup)"
    Step-Delay

    $open = Test-TcpPort -Host $TargetHost -Port 445 -TimeoutMs 3000
    if ($open) {
        Write-Found "SMB port 445 OPEN on ${TargetHost}"
        # Attempt a net use — will fail auth but triggers SMB decoy
        $null = net use "\\${TargetHost}\CorpShare" /user:'CORP\svc-backup' 'BackupSvc!2024fake' 2>$null
        Write-Alert "CRITICAL — Decoy SMB share probed: \\${TargetHost}\CorpShare"
        Write-Alert "           Credential: CORP\svc-backup (from Windows Credential Manager)"
        Write-Log DECOY_HIT "SMB probe: \\${TargetHost}\CorpShare"
        $null = net use "\\${TargetHost}\CorpShare" /delete /y 2>$null
    } else {
        Write-Info "SMB (445) not open on ${TargetHost} — skipping SMB decoy probe."
    }

    Write-Host ""
    Write-Info "Phase 4 complete."
    Write-Info "DEMO: Deception portal should show multiple CRITICAL alerts. Check:"
    Write-Info "      Alerts → Active Alerts  |  Investigation → Attack Timeline"
    Write-Log INFO "Phase 4 complete"
}

# ---------------------------------------------------------------------------
# Phase 5 – Post-Exploitation Probes
# ---------------------------------------------------------------------------
function Invoke-Phase5 {
    Write-Phase 5 "Post-Exploitation: Cloud Token Abuse + Lateral Movement Probes"

    # ── 5a: Fake AWS canary token call ───────────────────────────────────────
    Write-Action "Using fake AWS access key (canary token) in an STS API call…"
    Write-Info   "Key: DEMO-FAKE-KEY-ID-WIN-LAB1-REPLACE  (this triggers a cloud canary alert)"
    Step-Delay

    $awsUri = 'https://sts.amazonaws.com/?Action=GetCallerIdentity&Version=2011-06-15'
    try {
        $headers = @{
            'Authorization' = 'AWS4-HMAC-SHA256 Credential=DEMO-FAKE-KEY-ID-WIN-LAB1-REPLACE/20241101/us-east-1/sts/aws4_request, SignedHeaders=host;x-amz-date, Signature=fakesig'
            'X-Amz-Date'    = '20241101T000000Z'
        }
        $resp = Invoke-WebRequest -Uri $awsUri -Headers $headers -TimeoutSec 8 -UseBasicParsing
        Write-Found "AWS STS responded: HTTP $($resp.StatusCode)"
        Write-Dim   "    $($resp.Content.Substring(0, [Math]::Min(120, $resp.Content.Length)))"
    } catch {
        Write-Info "AWS STS call attempted (canary token sent — alert fires in Deception portal)"
    }
    Write-Alert "Deception Canary Token USED — Fake AWS key DEMO-FAKE-KEY-ID-WIN-LAB1-REPLACE"
    Write-Alert "Cloud API call originated from: $env:COMPUTERNAME"
    Write-Log CANARY_TOKEN "AWS key DEMO-FAKE-KEY-ID-WIN-LAB1-REPLACE used in STS call"
    Write-Host ""
    Step-Delay

    # ── 5b: Additional backend service probes ────────────────────────────────
    Write-Action "Probing additional internal backend services…"
    $extraPorts = @(
        @{ Port = 5432;  Label = "PostgreSQL" },
        @{ Port = 1433;  Label = "SQL Server" },
        @{ Port = 27017; Label = "MongoDB"    },
        @{ Port = 6379;  Label = "Redis"      }
    )
    foreach ($svc in $extraPorts) {
        $open = Test-TcpPort -Host $TargetHost -Port $svc.Port
        if ($open) {
            Write-Found "${TargetHost}:$($svc.Port)  — $($svc.Label) OPEN"
        } else {
            Write-Dim   "${TargetHost}:$($svc.Port)  — $($svc.Label) closed"
        }
        Start-Sleep -Milliseconds 300
    }
    Write-Host ""
    Step-Delay

    # ── 5c: Data staging simulation ──────────────────────────────────────────
    Write-Action "Staging discovered credential files for exfiltration…"
    $stageDir = Join-Path $env:TEMP "attacker_stage_$(Get-Random)"
    New-Item -ItemType Directory -Path $stageDir -Force | Out-Null
    $filesToStage = @(
        "$env:USERPROFILE\.aws\credentials",
        "$env:USERPROFILE\Downloads\passwords_export.csv",
        "$env:USERPROFILE\Documents\Backups\db_backup.sql"
    )
    $staged = 0
    foreach ($f in $filesToStage) {
        if (Test-Path $f) {
            Copy-Item $f -Destination $stageDir -Force -ErrorAction SilentlyContinue
            $staged++
        }
    }
    Write-Found "Staged ${staged} file(s) in ${stageDir}"
    Write-Dim   "    Files: $((Get-ChildItem $stageDir).Name -join ', ')"
    # Clean up staging dir immediately
    Remove-Item $stageDir -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host ""

    Write-Info "Phase 5 complete."
    Write-Info "DEMO: The Deception portal's attack timeline is now fully populated."
    Write-Log INFO "Phase 5 complete"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
Clear-Host
Write-Host ""
Write-Host "  ╔══════════════════════════════════════════════════════════╗" -ForegroundColor Magenta
Write-Host "  ║    Zscaler Deception — Attacker Simulation (Windows)    ║" -ForegroundColor Magenta
Write-Host "  ╚══════════════════════════════════════════════════════════╝" -ForegroundColor Magenta
Write-Host ""
Write-Info "Target Host  : $TargetHost"
Write-Info "Subnet       : $Subnet"
Write-Info "Log File     : $LogFile"
Write-Host ""
Write-Host "  WARNING: Authorised lab environments only." -ForegroundColor Red
Write-Host ""
Write-Host "  Colour key:" -ForegroundColor Cyan
Write-Host "  [DECEPTION ALERT EXPECTED] = this action should trigger a Deception alert" -ForegroundColor Red
Write-Host "  [ATTACKER ACTION]          = what the simulated attacker is doing"          -ForegroundColor Yellow
Write-Host "  [FOUND]                    = attacker discovered something"                  -ForegroundColor Green
Write-Host ""

if (-not $NoPause) {
    Write-Host "  ↵  Press Enter to begin the attacker simulation…" -ForegroundColor DarkGray
    $null = Read-Host
}

$phasesToRun = if ($Phase -gt 0) { @($Phase) } else { @(1,2,3,4,5) }

foreach ($p in $phasesToRun) {
    switch ($p) {
        1 { Invoke-Phase1 }
        2 { Invoke-Phase2 }
        3 { Invoke-Phase3 }
        4 { Invoke-Phase4 }
        5 { Invoke-Phase5 }
    }
    if ($phasesToRun.Count -gt 1 -and $p -lt $phasesToRun[-1]) {
        Pause-Phase
    }
}

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "  ══════════════════════════════════════════════════════════" -ForegroundColor Magenta
Write-Host "   Attacker Simulation Complete" -ForegroundColor Magenta
Write-Host "  ══════════════════════════════════════════════════════════" -ForegroundColor Magenta
Write-Host ""
Write-Host "  Simulated attack triggered the following Deception events:" -ForegroundColor White
Write-Host ""
Write-Host "  ● Deception lures accessed  — credential files read on endpoint"   -ForegroundColor Red
Write-Host "  ● SSH honeypot interaction  — ${TargetHost}:2222"                  -ForegroundColor Red
Write-Host "  ● Web portal login attempt  — ${TargetHost}:8081"                  -ForegroundColor Red
Write-Host "  ● Database probe            — ${TargetHost}:3307"                  -ForegroundColor Red
Write-Host "  ● SMB decoy probe           — \\${TargetHost}\CorpShare"           -ForegroundColor Red
Write-Host "  ● Cloud canary token used   — Fake AWS key in API call"            -ForegroundColor Red
Write-Host ""
Write-Host "  Next steps (in the Deception portal):" -ForegroundColor Cyan
Write-Host "  1. Navigate to Alerts → Active Alerts"
Write-Host "     Show all alerts — every one is CRITICAL or HIGH"
Write-Host "  2. Navigate to Investigation → Attack Timeline"
Write-Host "     Show full kill chain reconstructed automatically"
Write-Host "  3. Navigate to Investigation → Attack Graph"
Write-Host "     Show lateral movement visualisation"
Write-Host "  4. Click Respond → Isolate Endpoint on any CRITICAL alert"
Write-Host "     Show SOAR playbook execution (ZPA block + ZIA quarantine)"
Write-Host ""
Write-Info "Full simulation log: $LogFile"
Write-Host ""
