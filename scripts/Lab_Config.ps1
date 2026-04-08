<#
.SYNOPSIS
    Centralised lab configuration loader for PowerShell demo scripts.

.DESCRIPTION
    Dot-source this file at the top of any PowerShell demo script to pick up
    the user's personal lab settings from .env without hard-coding values.

        $LabRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
        . "$LabRoot\scripts\Lab_Config.ps1"

    Load order (last wins):
      1. Built-in defaults (below)
      2. <repo-root>\.env   – personal overrides (git-ignored)
      3. Script-level -Parameter flags – highest priority
#>

# ── Locate repo root ────────────────────────────────────────────────────────
$_LabConfigDir  = $PSScriptRoot
$_LabRepoRoot   = Split-Path $_LabConfigDir -Parent

# ── Source .env if present ───────────────────────────────────────────────────
$_EnvFile = Join-Path $_LabRepoRoot '.env'
if (Test-Path $_EnvFile) {
    Get-Content $_EnvFile | ForEach-Object {
        $line = $_.Trim()
        if ($line -and -not $line.StartsWith('#')) {
            $parts = $line -split '=', 2
            if ($parts.Count -eq 2) {
                [Environment]::SetEnvironmentVariable($parts[0].Trim(), $parts[1].Trim(), 'Process')
            }
        }
    }
}

# ── Defaults ─────────────────────────────────────────────────────────────────
if (-not $env:WINDOWS_SERVER_IP) { $env:WINDOWS_SERVER_IP = '192.168.1.20' }
if (-not $env:LINUX_SERVER_IP)   { $env:LINUX_SERVER_IP   = '192.168.1.10' }
if (-not $env:LAB_SUBNET)        { $env:LAB_SUBNET        = '192.168.1'    }
if (-not $env:LAB_SUBNET_CIDR)   { $env:LAB_SUBNET_CIDR   = '192.168.1.0/24' }

# ── Expose as script-scoped variables for easy use ───────────────────────────
$Script:LabWindowsServerIP = $env:WINDOWS_SERVER_IP
$Script:LabLinuxServerIP   = $env:LINUX_SERVER_IP
$Script:LabSubnet          = $env:LAB_SUBNET
$Script:LabSubnetCIDR      = $env:LAB_SUBNET_CIDR
