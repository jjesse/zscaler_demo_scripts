#Requires -Version 5.1
<#
.SYNOPSIS
    Generates continuous HTTPS traffic across multiple URL categories so ZIA
    Analytics dashboards and Log Explorer stay populated during a demo.

.DESCRIPTION
    Sends web requests to well-known sites in the following URL categories:
      - News
      - Social Media (Caution / Warn in ZIA)
      - Sports
      - Streaming / Entertainment
      - Business / Cloud Productivity
      - Blocked (P2P / threat – expect ZIA to intercept)

    Run this on the Windows 11 client while Zscaler Client Connector is
    connected (green tray icon). Every request passes through ZIA and is
    logged with full URL, category, user, and device context.

.PARAMETER Interval
    Seconds to wait between request rounds. Default: 30

.PARAMETER Count
    Number of rounds to run. 0 = run indefinitely until Ctrl-C. Default: 0

.EXAMPLE
    .\scripts\zia\windows\generate_zia_traffic.ps1
    .\scripts\zia\windows\generate_zia_traffic.ps1 -Interval 15 -Count 5
#>

param(
    [int]$Interval = 30,
    [int]$Count    = 0
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Continue"

# ── Colour helpers ────────────────────────────────────────────────────────────
function Write-Allow   { param([string]$msg) Write-Host "  [ALLOW]  $msg" -ForegroundColor Green }
function Write-Block   { param([string]$msg) Write-Host "  [BLOCK]  $msg" -ForegroundColor Red }
function Write-Caution { param([string]$msg) Write-Host "  [WARN]   $msg" -ForegroundColor Yellow }
function Write-Info    { param([string]$msg) Write-Host "  [INFO]   $msg" -ForegroundColor Cyan }
function Write-Section { param([string]$msg) Write-Host "`n  ── $msg ──" -ForegroundColor Magenta }
function Get-Ts        { Get-Date -Format "HH:mm:ss" }

# ── URL lists by category ─────────────────────────────────────────────────────
$UrlCategories = [ordered]@{
    "News" = @{
        Expected = "Allow"
        Sites    = @(
            @{ Label = "CNN.com";        Url = "https://www.cnn.com" }
            @{ Label = "BBC.co.uk";      Url = "https://www.bbc.co.uk" }
            @{ Label = "Reuters.com";    Url = "https://www.reuters.com" }
            @{ Label = "APNews.com";     Url = "https://apnews.com" }
            @{ Label = "NPR.org";        Url = "https://www.npr.org" }
            @{ Label = "Guardian.com";   Url = "https://www.theguardian.com" }
        )
    }
    "Social Media" = @{
        Expected = "Warn"
        Sites    = @(
            @{ Label = "LinkedIn.com";   Url = "https://www.linkedin.com" }
            @{ Label = "Reddit.com";     Url = "https://www.reddit.com" }
            @{ Label = "Twitter/X.com";  Url = "https://twitter.com" }
            @{ Label = "Facebook.com";   Url = "https://www.facebook.com" }
            @{ Label = "Instagram.com";  Url = "https://www.instagram.com" }
        )
    }
    "Sports" = @{
        Expected = "Allow"
        Sites    = @(
            @{ Label = "ESPN.com";          Url = "https://www.espn.com" }
            @{ Label = "NFL.com";           Url = "https://www.nfl.com" }
            @{ Label = "NBA.com";           Url = "https://www.nba.com" }
            @{ Label = "MLB.com";           Url = "https://www.mlb.com" }
            @{ Label = "BleacherReport.com"; Url = "https://bleacherreport.com" }
        )
    }
    "Streaming" = @{
        Expected = "Allow"
        Sites    = @(
            @{ Label = "YouTube.com";    Url = "https://www.youtube.com" }
            @{ Label = "Twitch.tv";      Url = "https://www.twitch.tv" }
            @{ Label = "Spotify.com";    Url = "https://www.spotify.com" }
            @{ Label = "Vimeo.com";      Url = "https://vimeo.com" }
            @{ Label = "SoundCloud.com"; Url = "https://soundcloud.com" }
        )
    }
    "Business" = @{
        Expected = "Allow"
        Sites    = @(
            @{ Label = "Zscaler.com";    Url = "https://www.zscaler.com" }
            @{ Label = "Microsoft.com";  Url = "https://www.microsoft.com" }
            @{ Label = "Google.com";     Url = "https://www.google.com" }
            @{ Label = "GitHub.com";     Url = "https://github.com" }
            @{ Label = "Salesforce.com"; Url = "https://www.salesforce.com" }
            @{ Label = "Slack.com";      Url = "https://slack.com" }
            @{ Label = "Zoom.us";        Url = "https://zoom.us" }
            @{ Label = "Atlassian.com";  Url = "https://www.atlassian.com" }
            @{ Label = "Wikipedia.org";  Url = "https://www.wikipedia.org" }
        )
    }
    "Blocked" = @{
        Expected = "Block"
        Sites    = @(
            @{ Label = "BitTorrent.com (P2P)"; Url = "https://www.bittorrent.com" }
            @{ Label = "EICAR test (threat)";  Url = "http://malware.wicar.org/data/eicar.com" }
        )
    }
}

# ── Traffic function ──────────────────────────────────────────────────────────
function Invoke-ZIARequest {
    param(
        [string]$Label,
        [string]$Url,
        [ValidateSet('Allow','Block','Warn')]
        [string]$Expected
    )
    try {
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        $response = Invoke-WebRequest -Uri $Url -UseBasicParsing `
                    -TimeoutSec 12 -ErrorAction Stop `
                    -UserAgent "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
        $sw.Stop()
        $code = $response.StatusCode

        switch ($Expected) {
            'Allow' {
                if ($code -ge 200 -and $code -lt 400) {
                    Write-Allow "$Label → HTTP $code in $($sw.ElapsedMilliseconds)ms"
                } else {
                    Write-Info  "$Label → HTTP $code (may be blocked)"
                }
            }
            'Block' {
                Write-Caution "$Label → HTTP $code (expected block – check ZIA policy)"
            }
            'Warn' {
                Write-Caution "$Label → HTTP $code (Warn/Caution page expected in ZIA)"
            }
        }
    } catch [System.Net.WebException] {
        $status = $_.Exception.Status
        switch ($Expected) {
            'Block' { Write-Block  "$Label → $status (ZIA blocked as expected) ✓" }
            default { Write-Info   "$Label → $status (may be blocked by ZIA or unreachable)" }
        }
    } catch {
        Write-Info "$Label → $($_.Exception.GetType().Name)"
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
Write-Host " Sends HTTPS requests across multiple URL categories so ZIA"
Write-Host " Analytics dashboards and Log Explorer are populated for the demo."
Write-Host ""
Write-Host " Ensure Zscaler Client Connector is connected (green tray icon)"
Write-Host " before running."
Write-Host ""
Write-Host " Press Ctrl-C to stop."
Write-Host ""

$iteration = 0

while ($true) {
    $iteration++
    Write-Host "--- Cycle $iteration ($(Get-Ts)) ---" -ForegroundColor Blue

    foreach ($category in $UrlCategories.Keys) {
        $cat  = $UrlCategories[$category]
        Write-Section "Category: $category"
        foreach ($site in $cat.Sites) {
            Invoke-ZIARequest -Label $site.Label -Url $site.Url -Expected $cat.Expected
            Start-Sleep -Seconds 1
        }
    }

    Write-Host ""
    if ($Count -gt 0 -and $iteration -ge $Count) {
        Write-Host "$(Get-Ts) Reached max count ($Count). Exiting." -ForegroundColor Cyan
        break
    }

    Write-Host "$(Get-Ts) Sleeping $Interval s before next round..." -ForegroundColor Gray
    Start-Sleep -Seconds $Interval
}
