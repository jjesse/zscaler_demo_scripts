#Requires -Version 5.1
<#
.SYNOPSIS
    Generates continuous internet traffic through ZIA for demo purposes.

.DESCRIPTION
    Sends HTTP/HTTPS requests to a mix of allowed, warned, and blocked
    destinations so that ZIA Analytics dashboards are populated before or
    during the customer demo.

    Runs indefinitely. Press Ctrl-C to stop.

.EXAMPLE
    .\scripts\zia\windows\generate_zia_traffic.ps1
#>

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'SilentlyContinue'

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
function Write-Allow  { param($Msg) Write-Host "[ALLOW]  $Msg" -ForegroundColor Green }
function Write-Block  { param($Msg) Write-Host "[BLOCK]  $Msg" -ForegroundColor Red }
function Write-Caution{ param($Msg) Write-Host "[WARN]   $Msg" -ForegroundColor Yellow }
function Write-Info   { param($Msg) Write-Host "[INFO]   $Msg" -ForegroundColor Cyan }

function Get-Timestamp { return (Get-Date -Format 'HH:mm:ss') }

function Invoke-ZIARequest {
    param(
        [string]$Label,
        [string]$Url,
        [ValidateSet('Allow','Block','Warn')]
        [string]$Expected
    )

    try {
        $response = Invoke-WebRequest -Uri $Url -TimeoutSec 10 -UseBasicParsing
        $code = $response.StatusCode
    } catch {
        $code = 0
    }

    switch ($Expected) {
        'Allow' {
            if ($code -ge 200 -and $code -lt 400) { Write-Allow  "$Label → HTTP $code" }
            else                                    { Write-Info   "$Label → HTTP $code (may be blocked)" }
        }
        'Block' {
            if ($code -eq 0 -or $code -ge 400)     { Write-Block  "$Label → blocked (HTTP $code)" }
            else                                    { Write-Caution "$Label → HTTP $code (expected block)" }
        }
        'Warn' {
            Write-Caution "$Label → HTTP $code (caution page expected)"
        }
    }
}

# ---------------------------------------------------------------------------
# Traffic targets
# ---------------------------------------------------------------------------
$AllowedSites = @(
    @{ Label = 'Microsoft.com';   Url = 'https://www.microsoft.com' }
    @{ Label = 'Google.com';      Url = 'https://www.google.com' }
    @{ Label = 'GitHub.com';      Url = 'https://github.com' }
    @{ Label = 'Wikipedia.org';   Url = 'https://www.wikipedia.org' }
    @{ Label = 'Bing.com';        Url = 'https://www.bing.com' }
    @{ Label = 'LinkedIn.com';    Url = 'https://www.linkedin.com' }
)

$CautionSites = @(
    @{ Label = 'Reddit.com';      Url = 'https://www.reddit.com' }
    @{ Label = 'Twitter/X.com';   Url = 'https://twitter.com' }
)

$BlockedSites = @(
    @{ Label = 'BitTorrent.com';  Url = 'https://www.bittorrent.com' }
    @{ Label = 'EICAR test file'; Url = 'http://malware.wicar.org/data/eicar.com' }
)

# ---------------------------------------------------------------------------
# Main loop
# ---------------------------------------------------------------------------
Write-Info "=== ZIA Traffic Generator Started ==="
Write-Info "Traffic is flowing through ZIA. Press Ctrl-C to stop."
Write-Host ""

$Cycle = 0
while ($true) {
    $Cycle++
    Write-Host "--- Cycle $Cycle ($(Get-Timestamp)) ---" -ForegroundColor Blue

    foreach ($site in $AllowedSites) {
        Invoke-ZIARequest -Label $site.Label -Url $site.Url -Expected Allow
        Start-Sleep -Seconds 1
    }

    foreach ($site in $CautionSites) {
        Invoke-ZIARequest -Label $site.Label -Url $site.Url -Expected Warn
        Start-Sleep -Seconds 1
    }

    foreach ($site in $BlockedSites) {
        Invoke-ZIARequest -Label $site.Label -Url $site.Url -Expected Block
        Start-Sleep -Seconds 2
    }

    Write-Host ""
    Write-Info "Cycle $Cycle complete. Sleeping 30 seconds..."
    Start-Sleep -Seconds 30
}
