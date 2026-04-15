#Requires -Version 5.1
<#
.SYNOPSIS
    Master lab-reset script for the ZPA / ZIA / ZDX / Deception demo (Windows).

.DESCRIPTION
    Run this between demo sessions on the Windows 11 client or Windows Server
    to restore a clean, known-good baseline.  Suitable for:
      - Cleaning up between multiple back-to-back customer demos
      - Resetting after the ZDX "poor score" simulation
      - Removing deception tokens after the Deception demo
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

.PARAMETER Deception
    Remove deception tokens and clear attacker simulation logs.

.EXAMPLE
    # Full reset – all products
    .\scripts\reset_lab.ps1

    # ZDX only – stop poor-score simulation and restore good baseline
    .\scripts\reset_lab.ps1 -ZDX

    # ZPA only – stop traffic generators and clear log files
    .\scripts\reset_lab.ps1 -ZPA

    # Deception only – remove tokens and clear logs
    .\scripts\reset_lab.ps1 -Deception
#>

[CmdletBinding()]
param(
    [switch]$ZPA,
    [switch]$ZIA,
    [switch]$ZDX,
    [switch]$Deception
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Continue"

# ── Load centralised lab config (.env) ────────────────────────────────────────
$_LabCfg = Join-Path $PSScriptRoot 'Lab_Config.ps1'
if (Test-Path $_LabCfg) { . $_LabCfg }
$_LinuxIP = if ($env:LINUX_SERVER_IP) { $env:LINUX_SERVER_IP } else { '192.168.1.10' }

# ── Colour helpers ────────────────────────────────────────────────────────────
function Write-Ok      { param([string]$msg) Write-Host "  [OK]   $msg" -ForegroundColor Green }
function Write-Warn    { param([string]$msg) Write-Host "  [WARN] $msg" -ForegroundColor Yellow }
function Write-Info    { param([string]$msg) Write-Host "  [INFO] $msg" -ForegroundColor Cyan }
function Write-Section { param([string]$msg) Write-Host "`n  ━━━ $msg ━━━" -ForegroundColor Cyan }

# If no specific switch, reset everything
$ResetAll       = -not ($ZPA -or $ZIA -or $ZDX -or $Deception)
$ResetZPA       = $ZPA       -or $ResetAll
$ResetZIA       = $ZIA       -or $ResetAll
$ResetZDX       = $ZDX       -or $ResetAll
$ResetDeception = $Deception -or $ResetAll

# ── Helper: stop jobs/processes matching a name pattern ───────────────────────
function Stop-DemoProcess {
    param([string]$Pattern, [string]$Label)
    $procs = Get-Process -ErrorAction SilentlyContinue |
             Where-Object { $_.MainWindowTitle -like "*$Pattern*" -or $_.Name -like "*$Pattern*" }
    if ($procs) {
        $procs | ForEach-Object {
            try {
                $_.Kill()
            } catch {
                # Process may have already exited – not an error
            }
        }
        Write-Ok "Stopped process: $Label"
    }
    # Also stop any PowerShell jobs with matching command
    $jobs = Get-Job -State Running -ErrorAction SilentlyContinue |
            Where-Object { $_.Command -like "*$Pattern*" }
    if ($jobs) {
        $jobs | Stop-Job -ErrorAction SilentlyContinue
        $jobs | Remove-Job -Force -ErrorAction SilentlyContinue
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

# ── Deception Reset ───────────────────────────────────────────────────────────
if ($ResetDeception) {
    Write-Section "Deception – Remove Tokens and Clear Attacker Simulation Logs"

    Stop-DemoProcess -Pattern "simulate_attacker"    -Label "Deception attacker simulation"
    Stop-DemoProcess -Pattern "deploy_deception_tokens" -Label "Deception token deployer"

    # Remove deployed token files
    $tokenPaths = @(
        "$env:USERPROFILE\.aws\credentials",
        "$env:USERPROFILE\.ssh\config",
        "$env:USERPROFILE\Documents\Projects\webapp\.env",
        "$env:USERPROFILE\Documents\Backups\db_backup.sql",
        "$env:USERPROFILE\Downloads\passwords_export.csv",
        "$env:USERPROFILE\Documents\vault_location.txt"
    )
    foreach ($path in $tokenPaths) {
        if (Test-Path $path) {
            Remove-Item $path -Force -ErrorAction SilentlyContinue
            Write-Ok "Removed token: $path"
        }
    }

    # Remove the fake SMB credential from Credential Manager
    $null = cmdkey /delete:"\\$_LinuxIP\CorpShare" 2>$null
    Write-Ok "Removed fake SMB entry from Windows Credential Manager"

    # Remove attacker simulation log
    $simLog = "$env:TEMP\deception_attacker_sim.log"
    if (Test-Path $simLog) {
        Remove-Item $simLog -Force -ErrorAction SilentlyContinue
        Write-Ok "Removed attacker simulation log: $simLog"
    }

    # Clean up empty directories we created
    $dirsToClean = @(
        "$env:USERPROFILE\.aws",
        "$env:USERPROFILE\Documents\Projects\webapp",
        "$env:USERPROFILE\Documents\Projects",
        "$env:USERPROFILE\Documents\Backups"
    )
    foreach ($dir in $dirsToClean) {
        if (Test-Path $dir) {
            $items = Get-ChildItem $dir -ErrorAction SilentlyContinue
            if (-not $items) {
                Remove-Item $dir -Force -ErrorAction SilentlyContinue
            }
        }
    }

    Write-Ok "Deception reset complete"
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
if ($ResetDeception) {
    Write-Host "  • Deception: Re-deploy tokens on Windows endpoints before next meeting:"
    Write-Host "    .\scripts\deception\windows\deploy_deception_tokens.ps1"
    Write-Host "    Confirm Deception portal: all decoys Active, alerts cleared."
}
Write-Host ""
