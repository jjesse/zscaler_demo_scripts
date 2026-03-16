#Requires -Version 5.1
<#
.SYNOPSIS
    Demonstrates ZPA policy blocks by attempting connections to applications
    the current user is NOT entitled to access.

.DESCRIPTION
    This script is the key demo for "Act 3 – Policy Blocks" in the ZPA Demo
    Guide. It runs from the Windows 11 client while the ZPA Client Connector
    is active, and attempts to reach:

      - http://192.168.1.20:9090  (Shadow IT app – no access policy)
      - \\192.168.1.20\HiddenShare (non-existent / unauthorised share)
      - Additional unauthorised TCP ports

    Every attempt should fail because ZPA has no allow rule for these
    destinations. Results are logged to the console and optionally to a file.

.PARAMETER TargetHost
    IP of the Windows Server. Default: 192.168.1.20

.PARAMETER LogFile
    Path to write results log. Default: $env:TEMP\zpa_block_demo.log

.PARAMETER RepeatCount
    Number of times to run the full attempt set. Default: 3

.EXAMPLE
    .\demo_policy_blocks.ps1
    .\demo_policy_blocks.ps1 -TargetHost 192.168.1.20 -RepeatCount 5
#>

param(
    [string]$TargetHost   = "192.168.1.20",
    [string]$LogFile      = "$env:TEMP\zpa_block_demo.log",
    [int]$RepeatCount     = 3
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Continue"

# ── Logging ───────────────────────────────────────────────────────────────────
function Write-Log {
    param([string]$Level, [string]$Message)
    $ts   = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[$ts] [$Level] $Message"
    Add-Content -Path $LogFile -Value $line

    switch ($Level) {
        "BLOCKED" { Write-Host $line -ForegroundColor Green  }   # green = good! blocked as expected
        "ALLOWED" { Write-Host $line -ForegroundColor Red    }   # red = unexpected allow
        "INFO"    { Write-Host $line -ForegroundColor Cyan   }
        "ERROR"   { Write-Host $line -ForegroundColor Yellow }
    }
}

function Write-Banner { param([string]$Text)
    Write-Host ""
    Write-Host ("=" * 64) -ForegroundColor Cyan
    Write-Host "  $Text" -ForegroundColor Cyan
    Write-Host ("=" * 64) -ForegroundColor Cyan
}

# ── Attempt functions ─────────────────────────────────────────────────────────

function Test-BlockedHttp {
    param([string]$Url)
    Write-Log "INFO" "Attempting HTTP: $Url"
    try {
        $response = Invoke-WebRequest -Uri $Url -UseBasicParsing `
                    -TimeoutSec 8 -ErrorAction Stop
        # If we got here, the connection was NOT blocked
        Write-Log "ALLOWED" "UNEXPECTED SUCCESS: $Url returned HTTP $($response.StatusCode)"
        Write-Log "ALLOWED" ">>> Check ZPA policy – this app should be blocked! <<<"
    } catch [System.Net.WebException] {
        $status = $_.Exception.Status
        Write-Log "BLOCKED" "Expected block confirmed: $Url -> $status (request never reached server)"
    } catch {
        Write-Log "BLOCKED" "Expected block confirmed: $Url -> $($_.Exception.GetType().Name)"
    }
}

function Test-BlockedTcp {
    param([string]$HostName, [int]$Port, [string]$Label)
    Write-Log "INFO" "Attempting TCP connection: ${HostName}:${Port} ($Label)"
    try {
        $tcp = [System.Net.Sockets.TcpClient]::new()
        $result = $tcp.BeginConnect($HostName, $Port, $null, $null)
        $connected = $result.AsyncWaitHandle.WaitOne(5000)
        $tcp.Close()
        if ($connected) {
            Write-Log "ALLOWED" "UNEXPECTED SUCCESS: TCP ${HostName}:${Port} ($Label) is open"
            Write-Log "ALLOWED" ">>> Check ZPA policy – this port should be blocked! <<<"
        } else {
            Write-Log "BLOCKED" "Expected block confirmed: TCP ${HostName}:${Port} ($Label) timed out"
        }
    } catch {
        Write-Log "BLOCKED" "Expected block confirmed: TCP ${HostName}:${Port} -> $($_.Exception.Message)"
    }
}

function Test-BlockedSmb {
    param([string]$SharePath)
    Write-Log "INFO" "Attempting SMB access: $SharePath"
    try {
        $items = Get-ChildItem -Path $SharePath -ErrorAction Stop
        Write-Log "ALLOWED" "UNEXPECTED SUCCESS: $SharePath returned $($items.Count) item(s)"
        Write-Log "ALLOWED" ">>> This share should be blocked by ZPA policy! <<<"
    } catch {
        Write-Log "BLOCKED" "Expected block confirmed: $SharePath -> $($_.Exception.Message)"
    }
}

# ── Main ──────────────────────────────────────────────────────────────────────
Write-Banner "ZPA Policy Block Demo"
Write-Log "INFO" "Target host  : $TargetHost"
Write-Log "INFO" "Log file     : $LogFile"
Write-Log "INFO" "Repeat count : $RepeatCount"
Write-Log "INFO" "ZPA Client should be CONNECTED for this demo."
Write-Log "INFO" "All connections below should be BLOCKED (shown in green)."
Write-Host ""

# Brief explanation for the demo audience
Write-Host @"
DEMO NARRATIVE:
  The following connections target services that exist on the Windows Server
  but are NOT covered by any ZPA allow policy for this user.

  ZPA enforces least-privilege: even though the app is running, it is
  invisible to the network. The connection attempt never reaches the server.

  GREEN = BLOCKED (expected/desired)
  RED   = ALLOWED (unexpected – check your policy!)
"@ -ForegroundColor White

for ($i = 1; $i -le $RepeatCount; $i++) {
    Write-Host ""
    Write-Log "INFO" "--- Round $i of $RepeatCount ---"

    # Blocked HTTP (Shadow IT app on port 9090)
    Test-BlockedHttp -Url "http://$TargetHost:9090/"

    # Blocked TCP – database port (not in any Application Segment)
    Test-BlockedTcp -HostName $TargetHost -Port 1433 -Label "SQL Server"
    Test-BlockedTcp -HostName $TargetHost -Port 5432 -Label "PostgreSQL"
    Test-BlockedTcp -HostName $TargetHost -Port 6379 -Label "Redis"

    # Blocked SMB share (share that doesn't exist in the policy)
    Test-BlockedSmb -SharePath "\\$TargetHost\HiddenShare"

    if ($i -lt $RepeatCount) {
        Start-Sleep -Seconds 3
    }
}

# ── Summary ───────────────────────────────────────────────────────────────────
Write-Host ""
Write-Banner "Block Demo Complete"

$logContent = Get-Content -Path $LogFile -ErrorAction SilentlyContinue
$blockedCount  = ($logContent | Select-String "\[BLOCKED\]").Count
$allowedCount  = ($logContent | Select-String "\[ALLOWED\]").Count

Write-Host ""
Write-Host "  Results from this run:" -ForegroundColor White
Write-Host "    BLOCKED (expected) : $blockedCount" -ForegroundColor Green
Write-Host "    ALLOWED (unexpected): $allowedCount" -ForegroundColor $(if ($allowedCount -gt 0) { "Red" } else { "Green" })
Write-Host ""
Write-Host "  Full log: $LogFile" -ForegroundColor White
Write-Host ""
Write-Host "  Now open the ZPA Admin Portal → Log Explorer and filter by" -ForegroundColor White
Write-Host "  this machine's user to see the BLOCK entries for each attempt." -ForegroundColor White
Write-Host ""

if ($allowedCount -gt 0) {
    Write-Host "  WARNING: $allowedCount connection(s) succeeded unexpectedly!" -ForegroundColor Red
    Write-Host "  Review your ZPA Access Policy to ensure Lab-Shadow-App" -ForegroundColor Red
    Write-Host "  is NOT covered by any allow rule." -ForegroundColor Red
}
