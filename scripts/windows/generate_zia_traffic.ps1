#Requires -Version 5.1
<#
.SYNOPSIS
    Generates continuous HTTPS traffic to public internet destinations across
    multiple URL categories so ZIA dashboards and Log Explorer stay populated
    during a demo.

.DESCRIPTION
    Sends web requests to well-known sites in the following URL categories:
      - News
      - Social Media
      - Sports
      - Streaming / Entertainment
      - Business / Cloud Productivity
      - Search Engines

    Run this on the Windows 11 client while Zscaler Client Connector is
    connected (green tray icon). Every request passes through ZIA and is
    logged with full URL, category, user, and device context.

.PARAMETER Interval
    Seconds to wait between request rounds. Default: 15

.PARAMETER Count
    Number of rounds to run. 0 = run indefinitely until Ctrl-C. Default: 0

.EXAMPLE
    .\generate_zia_traffic.ps1
    .\generate_zia_traffic.ps1 -Interval 30 -Count 5
#>

param(
    [int]$Interval = 15,
    [int]$Count    = 0
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Continue"

# ── Colour helpers ────────────────────────────────────────────────────────────
function Write-Ok      { param([string]$msg) Write-Host "  [OK]    $msg" -ForegroundColor Green }
function Write-Skip    { param([string]$msg) Write-Host "  [SKIP]  $msg" -ForegroundColor DarkYellow }
function Write-Section { param([string]$msg) Write-Host "`n  --- $msg ---" -ForegroundColor Yellow }
function Get-Ts        { Get-Date -Format "yyyy-MM-dd HH:mm:ss" }

# ── URL lists by category ─────────────────────────────────────────────────────
$UrlCategories = [ordered]@{
    "News" = @(
        "https://www.cnn.com"
        "https://www.bbc.co.uk"
        "https://www.reuters.com"
        "https://apnews.com"
        "https://www.npr.org"
        "https://www.theguardian.com"
    )
    "Social Media" = @(
        "https://www.linkedin.com"
        "https://www.reddit.com"
        "https://twitter.com"
        "https://www.facebook.com"
        "https://www.instagram.com"
    )
    "Sports" = @(
        "https://www.espn.com"
        "https://www.nfl.com"
        "https://www.nba.com"
        "https://www.mlb.com"
        "https://www.nhl.com"
        "https://bleacherreport.com"
    )
    "Streaming" = @(
        "https://www.youtube.com"
        "https://www.twitch.tv"
        "https://www.spotify.com"
        "https://vimeo.com"
        "https://soundcloud.com"
    )
    "Business" = @(
        "https://www.microsoft.com"
        "https://www.salesforce.com"
        "https://slack.com"
        "https://zoom.us"
        "https://github.com"
        "https://www.atlassian.com"
        "https://www.google.com"
    )
}

# ── Traffic function ──────────────────────────────────────────────────────────
function Invoke-CategoryRequest {
    param(
        [string]$Url,
        [string]$Category
    )
    try {
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        $response = Invoke-WebRequest -Uri $Url -UseBasicParsing `
                    -TimeoutSec 12 -ErrorAction Stop `
                    -UserAgent "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
        $sw.Stop()
        Write-Ok "[$Category] $Url -> HTTP $($response.StatusCode) in $($sw.ElapsedMilliseconds) ms"
    } catch [System.Net.WebException] {
        $status = $_.Exception.Status
        # A ZIA block page may return HTTP 200 with block content, or cause
        # a connection-level failure for blocked categories
        Write-Skip "[$Category] $Url -> $status (may be blocked by ZIA policy)"
    } catch {
        Write-Skip "[$Category] $Url -> $($_.Exception.GetType().Name)"
    }
}

# ── Main loop ─────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host " ZIA Traffic Generator – Windows Client" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  Interval : $Interval s"
Write-Host "  Count    : $(if ($Count -eq 0) { 'infinite' } else { $Count })"
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host " This script sends HTTPS requests to public sites in multiple"
Write-Host " URL categories so ZIA URL-Filtering and Analytics dashboards"
Write-Host " show real, categorised traffic during your demo."
Write-Host ""
Write-Host " Ensure Zscaler Client Connector is connected (green tray icon)"
Write-Host " before running."
Write-Host ""
Write-Host " Press Ctrl-C to stop."
Write-Host ""

$iteration = 0

while ($true) {
    $iteration++
    Write-Host ""
    Write-Host "$(Get-Ts) == Iteration $iteration ==" -ForegroundColor Magenta

    foreach ($category in $UrlCategories.Keys) {
        Write-Section "Category: $category"
        foreach ($url in $UrlCategories[$category]) {
            Invoke-CategoryRequest -Url $url -Category $category
            Start-Sleep -Seconds 1
        }
    }

    if ($Count -gt 0 -and $iteration -ge $Count) {
        Write-Host ""
        Write-Host "$(Get-Ts) Reached max count ($Count). Exiting." -ForegroundColor Cyan
        break
    }

    Write-Host ""
    Write-Host "$(Get-Ts) Sleeping $Interval s before next round..." -ForegroundColor Gray
    Start-Sleep -Seconds $Interval
}
