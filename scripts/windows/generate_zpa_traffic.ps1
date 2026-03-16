#Requires -Version 5.1
<#
.SYNOPSIS
    Generates continuous HTTP, HTTPS, SMB, and RDP traffic from the Windows 11
    client machine through ZPA to the Windows Server.

.DESCRIPTION
    Runs rounds of requests to private applications that are accessible only
    through Zscaler Private Access. This keeps the ZPA Analytics dashboards and
    Log Explorer populated during a demo.

    Run this script on the WINDOWS 11 CLIENT (not the server) while the ZPA
    Client Connector is connected.

.PARAMETER TargetHost
    IP address or hostname of the Windows Server running the internal apps.
    Default: 192.168.1.20

.PARAMETER Interval
    Seconds to wait between request rounds. Default: 10

.PARAMETER Count
    Number of iterations to run. 0 = run indefinitely until Ctrl-C.
    Default: 0

.EXAMPLE
    .\generate_zpa_traffic.ps1
    .\generate_zpa_traffic.ps1 -TargetHost 192.168.1.20 -Interval 15 -Count 30
#>

param(
    [string]$TargetHost = "192.168.1.20",
    [int]$Interval      = 10,
    [int]$Count         = 0
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Continue"

# ── Colour helpers ────────────────────────────────────────────────────────────
function Write-OK      { param([string]$msg) Write-Host "  [OK]    $msg" -ForegroundColor Green }
function Write-Fail    { param([string]$msg) Write-Host "  [FAIL]  $msg" -ForegroundColor Red }
function Write-Section { param([string]$msg) Write-Host "`n  --- $msg ---" -ForegroundColor Yellow }
function Get-Timestamp { Get-Date -Format "yyyy-MM-dd HH:mm:ss" }

# ── Traffic functions ─────────────────────────────────────────────────────────

function Invoke-HttpRequest {
    param([string]$Url, [string]$Label)
    Write-Section $Label
    try {
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        $response = Invoke-WebRequest -Uri $Url -UseBasicParsing `
                    -TimeoutSec 10 -ErrorAction Stop
        $sw.Stop()
        Write-OK "$Label -> HTTP $($response.StatusCode) in $($sw.ElapsedMilliseconds) ms"
    } catch {
        Write-Fail "$Label -> $($_.Exception.Message)"
    }
}

function Test-TcpPort {
    param([string]$Host, [int]$Port, [string]$Label)
    Write-Section $Label
    try {
        $tcp = [System.Net.Sockets.TcpClient]::new()
        $result = $tcp.BeginConnect($Host, $Port, $null, $null)
        $connected = $result.AsyncWaitHandle.WaitOne(5000)
        $tcp.Close()
        if ($connected) {
            Write-OK "$Label -> TCP $Port is open"
        } else {
            Write-Fail "$Label -> TCP $Port timed out"
        }
    } catch {
        Write-Fail "$Label -> $($_.Exception.Message)"
    }
}

function Invoke-SmbAccess {
    param([string]$SharePath, [string]$Label)
    Write-Section $Label
    try {
        $items = Get-ChildItem -Path $SharePath -ErrorAction Stop
        Write-OK "$Label -> Listed $($items.Count) item(s) in $SharePath"
    } catch {
        Write-Fail "$Label -> $($_.Exception.Message)"
    }
}

# ── Main loop ─────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host " ZPA Traffic Generator – Windows Client" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  Target    : $TargetHost"
Write-Host "  Interval  : $Interval s"
Write-Host "  Count     : $(if ($Count -eq 0) { 'infinite' } else { $Count })"
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  Press Ctrl-C to stop."
Write-Host ""

$iteration = 0

while ($true) {
    $iteration++
    Write-Host ""
    Write-Host "$(Get-Timestamp) == Iteration $iteration ==" -ForegroundColor Cyan

    # HTTP requests
    Invoke-HttpRequest -Url "http://$TargetHost/"       -Label "HTTP port 80"
    Invoke-HttpRequest -Url "http://$TargetHost:8080/"  -Label "HTTP port 8080"

    # HTTPS (skip cert validation for self-signed lab cert)
    # PowerShell 5 workaround for self-signed certs
    try {
        Add-Type -TypeDefinition @"
using System.Net; using System.Security.Cryptography.X509Certificates;
public class TrustAll : ICertificatePolicy {
    public bool CheckValidationResult(ServicePoint sp, X509Certificate cert,
        WebRequest req, int problem) { return true; }
}
"@ -ErrorAction SilentlyContinue
        [System.Net.ServicePointManager]::CertificatePolicy = [TrustAll]::new()
    } catch {}

    Invoke-HttpRequest -Url "https://$TargetHost/"      -Label "HTTPS port 443"

    # TCP probes (RDP, SSH)
    Test-TcpPort -Host $TargetHost -Port 3389 -Label "RDP port 3389"
    Test-TcpPort -Host $TargetHost -Port 22   -Label "SSH port 22"
    Test-TcpPort -Host $TargetHost -Port 445  -Label "SMB port 445"

    # SMB file share access
    Invoke-SmbAccess -SharePath "\\$TargetHost\LabShare" -Label "SMB LabShare"

    if ($Count -gt 0 -and $iteration -ge $Count) {
        Write-Host ""
        Write-Host "$(Get-Timestamp) Reached max count ($Count). Exiting." -ForegroundColor Cyan
        break
    }

    Write-Host ""
    Write-Host "$(Get-Timestamp) Sleeping $Interval s before next round..." -ForegroundColor Gray
    Start-Sleep -Seconds $Interval
}
