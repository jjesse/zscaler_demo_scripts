#Requires -Version 5.1
<#
.SYNOPSIS
    Master lab-reset script for the ZPA / ZIA / ZDX demo (Windows).

.DESCRIPTION
    Run this between demo sessions on the Windows 11 client or Windows Server
    to restore a clean, known-good baseline.  Suitable for:
      - Cleaning up between multiple back-to-back customer demos
      - Resetting after the ZDX "poor score" simulation
      - Clearing log files and stopping background traffic generators

    The script stops all background demo processes, clears log files, and
    optionally launches the ZDX good-score baseline probes to repopulate
    the portal before the next meeting.

.PARAMETER ZPA
    Reset ZPA-related processes only.

.PARAMETER ZIA
    Reset ZIA-related processes only.

.PARAMETER ZDX
    Reset ZDX-related processes (stop poor-score simulation, restore baseline).

.EXAMPLE
    # Full reset – all products
    .\scripts\reset_lab.ps1

    # ZDX only – stop poor-score simulation and restore good baseline
    .\scripts\reset_lab.ps1 -ZDX

    # ZPA only – stop traffic generators and clear log files
    .\scripts\reset_lab.ps1 -ZPA
#>

[CmdletBinding()]
param(
    [switch]$ZPA,
    [switch]$ZIA,
    [switch]$ZDX
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Continue"

# ── Colour helpers ────────────────────────────────────────────────────────────
function Write-Ok      { param([string]$msg) Write-Host "  [OK]   $msg" -ForegroundColor Green }
function Write-Warn    { param([string]$msg) Write-Host "  [WARN] $msg" -ForegroundColor Yellow }
function Write-Info    { param([string]$msg) Write-Host "  [INFO] $msg" -ForegroundColor Cyan }
function Write-Section { param([string]$msg) Write-Host "`n  ━━━ $msg ━━━" -ForegroundColor Cyan }

# If no specific switch, reset everything
$ResetAll = -not ($ZPA -or $ZIA -or $ZDX)
$ResetZPA = $ZPA -or $ResetAll
$ResetZIA = $ZIA -or $ResetAll
$ResetZDX = $ZDX -or $ResetAll

# ── Helper: stop jobs/processes matching a name pattern ───────────────────────
function Stop-DemoProcess {
    param([string]$Pattern, [string]$Label)
    $procs = Get-Process | Where-Object { $_.MainWindowTitle -like "*$Pattern*" -or $_.Name -like "*$Pattern*" }
    if ($procs) {
        $procs | ForEach-Object { $_.Kill() }
        Write-Ok "Stopped process: $Label"
    }
    # Also stop any PowerShell jobs with matching command
    $jobs = Get-Job -State Running -ErrorAction SilentlyContinue |
            Where-Object { $_.Command -like "*$Pattern*" }
    if ($jobs) {
        $jobs | Stop-Job
        $jobs | Remove-Job -Force
        Write-Ok "Stopped background job: $Label"
    }
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " Zscaler Demo Lab – Reset Script (Windows)" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

# ── ZPA Reset ─────────────────────────────────────────────────────────────────
if ($ResetZPA) {
    Write-Section "ZPA – Stop Traffic Generator and Clear Logs"

    Stop-DemoProcess -Pattern "generate_zpa_traffic" -Label "ZPA traffic generator"
    Stop-DemoProcess -Pattern "demo_policy_blocks"   -Label "ZPA policy blocks demo"
    Stop-DemoProcess -Pattern "demo_user_access"     -Label "ZPA user access demo"

    # Clear ZPA demo log files
    $zpaLogs = @(
        "$env:TEMP\zpa_user_access_demo.log"
        "$env:TEMP\zpa_policy_blocks_demo.log"
    )
    foreach ($log in $zpaLogs) {
        if (Test-Path $log) {
            Remove-Item $log -Force
            Write-Ok "Removed $log"
        }
    }

    Write-Ok "ZPA reset complete"
}

# ── ZIA Reset ─────────────────────────────────────────────────────────────────
if ($ResetZIA) {
    Write-Section "ZIA – Stop Traffic Generator and Clear Logs"

    Stop-DemoProcess -Pattern "generate_zia_traffic"  -Label "ZIA traffic generator"
    Stop-DemoProcess -Pattern "demo_threat_protection" -Label "ZIA threat protection demo"
    Stop-DemoProcess -Pattern "demo_cloud_app_control" -Label "ZIA cloud app control demo"
    Stop-DemoProcess -Pattern "demo_dlp"               -Label "ZIA DLP demo"

    # Clear ZIA demo log files
    $ziaLogs = @(
        "$env:TEMP\zia_block_demo.log"
        "$env:TEMP\zia_demo.log"
        "$env:TEMP\zia_dlp_demo.log"
        "$env:TEMP\zia_cloud_app_demo.log"
        "$env:TEMP\zia_threat_protection_demo.log"
    )
    foreach ($log in $ziaLogs) {
        if (Test-Path $log) {
            Remove-Item $log -Force
            Write-Ok "Removed $log"
        }
    }

    Write-Ok "ZIA reset complete"
}

# ── ZDX Reset ─────────────────────────────────────────────────────────────────
if ($ResetZDX) {
    Write-Section "ZDX – Restore Good Score Baseline"

    Stop-DemoProcess -Pattern "demo_zdx_scores" -Label "ZDX score simulation"

    # Kill any CPU stress background jobs
    $stressJobs = Get-Job -State Running -ErrorAction SilentlyContinue |
                  Where-Object { $_.Command -like "*cpu*" -or $_.Command -like "*stress*" }
    if ($stressJobs) {
        $stressJobs | Stop-Job
        $stressJobs | Remove-Job -Force
        Write-Ok "Stopped CPU stress jobs"
    }

    # Brief pause to let CPU settle
    Start-Sleep -Seconds 3

    # Report current device health
    $cpu = (Get-CimInstance -ClassName Win32_Processor |
            Measure-Object -Property LoadPercentage -Average).Average
    Write-Ok "Current CPU usage: $([int]$cpu)%"

    # Start the good-score baseline (3 rounds, background job)
    $zdxScript = Join-Path $PSScriptRoot "zdx\windows\demo_zdx_scores.ps1"
    if (Test-Path $zdxScript) {
        $null = Start-Job -ScriptBlock {
            param($script)
            & $script -Scenario Good -Iterations 3
        } -ArgumentList $zdxScript
        Write-Ok "Started ZDX good-score baseline (3 rounds in background)"
    } else {
        Write-Warn "ZDX script not found at $zdxScript"
        Write-Warn "Run manually: .\scripts\zdx\windows\demo_zdx_scores.ps1 -Scenario Good"
    }
}

# ── Summary ───────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host " Lab Reset Complete" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Pre-demo checklist:" -ForegroundColor White
Write-Host ""

if ($ResetZDX) {
    Write-Host "  • ZDX: Allow 5–10 min for the portal to reflect the restored score."
}
if ($ResetZPA) {
    Write-Host "  • ZPA: Confirm ZPA Client Connector shows 'Connected' (green icon)."
    Write-Host "    Pre-stage: .\scripts\zpa\windows\generate_zpa_traffic.ps1 -Count 5"
}
if ($ResetZIA) {
    Write-Host "  • ZIA: Pre-populate dashboards (run 10 min before the meeting):"
    Write-Host "    .\scripts\zia\windows\generate_zia_traffic.ps1 -Count 2"
}
Write-Host ""
