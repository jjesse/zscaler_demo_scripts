#Requires -Version 5.1
<#
.SYNOPSIS
    Demonstrates ZIA Cloud App Control — distinguishing sanctioned from
    unsanctioned cloud applications.

.DESCRIPTION
    Simulates upload/download activity to:
    - Sanctioned corporate cloud apps (allowed)
    - Personal / unsanctioned cloud storage (blocked)
    - Social media upload vs. view-only policy

    Run from a Windows 11 client with ZIA Client Connector installed
    and connected (green tray icon).

.EXAMPLE
    .\scripts\zia\windows\demo_cloud_app_control.ps1

.EXAMPLE
    .\scripts\zia\windows\demo_cloud_app_control.ps1 -Quiet
#>

[CmdletBinding()]
param(
    [switch]$Quiet
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'SilentlyContinue'

# ---------------------------------------------------------------------------
# Output helpers
# ---------------------------------------------------------------------------
function Write-Allow  { param($Msg) Write-Host "  [ALLOW]  $Msg" -ForegroundColor Green }
function Write-Block  { param($Msg) Write-Host "  [BLOCK]  $Msg" -ForegroundColor Red }
function Write-Caution{ param($Msg) Write-Host "  [WARN]   $Msg" -ForegroundColor Yellow }
function Write-Info   { param($Msg) Write-Host "  [INFO]   $Msg" -ForegroundColor Cyan }
function Write-Scene  { param($Msg) Write-Host "`n=== $Msg ===" -ForegroundColor Blue }
function Write-Sep    { Write-Host ('─' * 60) -ForegroundColor DarkGray }
function Pause-Demo   { if (-not $Quiet) { Read-Host "`n  ↵  Press Enter to continue" | Out-Null } }

# ---------------------------------------------------------------------------
# Helper: simulate an upload attempt (HTTP POST or GET)
# ---------------------------------------------------------------------------
function Test-CloudApp {
    param(
        [string]$Label,
        [string]$Url,
        [string]$Description,
        [ValidateSet('Allow','Block','Warn')]
        [string]$Expected,
        [string]$Method = 'GET'
    )

    Write-Host ""
    Write-Info "App    : $Label"
    Write-Info "URL    : $Url"
    Write-Info "Method : $Method"
    Write-Info "Expect : $Expected"

    try {
        if ($Method -eq 'POST') {
            # Simulate a small upload (multipart form)
            $body = [System.Text.Encoding]::UTF8.GetBytes("demo-file-content-for-zia-test")
            $response = Invoke-WebRequest -Uri $Url -Method POST -Body $body `
                -TimeoutSec 10 -UseBasicParsing
        } else {
            $response = Invoke-WebRequest -Uri $Url -Method GET `
                -TimeoutSec 10 -UseBasicParsing
        }
        $code = $response.StatusCode
    } catch {
        $code = 0
    }

    switch ($Expected) {
        'Allow' {
            if ($code -ge 200 -and $code -lt 400) { Write-Allow  "ALLOWED ✓  $Label (HTTP $code)" }
            else { Write-Caution "EXPECTED ALLOW │ $Label (HTTP $code)" }
        }
        'Block' {
            if ($code -eq 0 -or $code -ge 400)    { Write-Block  "BLOCKED ✓  $Label (HTTP $code)" }
            else { Write-Caution "EXPECTED BLOCK │ $Label (HTTP $code) — verify ZIA Cloud App policy" }
        }
        'Warn' {
            Write-Caution "CAUTION ✓  $Label (HTTP $code)"
        }
    }
    if ($Description) { Write-Info $Description }
}

# ---------------------------------------------------------------------------
# Introduction
# ---------------------------------------------------------------------------
Clear-Host
Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════╗" -ForegroundColor Magenta
Write-Host "║     ZIA Cloud Application Control Demo               ║" -ForegroundColor Magenta
Write-Host "╚══════════════════════════════════════════════════════╝" -ForegroundColor Magenta
Write-Host ""
Write-Info "This script demonstrates ZIA's ability to:"
Write-Info "  • Allow sanctioned corporate cloud applications"
Write-Info "  • Block unsanctioned / personal cloud storage uploads"
Write-Info "  • Apply view-only policies for social media"
Write-Info "  • Distinguish corporate vs. personal tenants of the same app"
Write-Host ""
Write-Info "ZIA Client Connector must be Connected (green tray icon)."
Write-Host ""
Pause-Demo

# ---------------------------------------------------------------------------
# Scene 1: Sanctioned Corporate Apps – Allowed
# ---------------------------------------------------------------------------
Write-Scene "Scene 1: Sanctioned Corporate Apps (Allowed)"
Write-Host ""
Write-Info "Talking track:"
Write-Info "  'These are the apps your employees need. ZIA inspects the traffic"
Write-Info "   but allows access because they are in the sanctioned app list.'"
Write-Host ""

Test-CloudApp `
    -Label       "Microsoft 365 (OneDrive)" `
    -Url         "https://onedrive.live.com" `
    -Expected    Allow `
    -Description "Corporate Microsoft 365 tenant — sanctioned by IT"

Test-CloudApp `
    -Label       "Google Workspace (Drive)" `
    -Url         "https://drive.google.com" `
    -Expected    Allow `
    -Description "Google Workspace corporate tenant — sanctioned"

Test-CloudApp `
    -Label       "Salesforce" `
    -Url         "https://www.salesforce.com" `
    -Expected    Allow `
    -Description "CRM system — sanctioned corporate application"

Pause-Demo

# ---------------------------------------------------------------------------
# Scene 2: Unsanctioned Personal Cloud Storage – Blocked
# ---------------------------------------------------------------------------
Write-Scene "Scene 2: Unsanctioned Personal Cloud Storage (Blocked)"
Write-Host ""
Write-Info "Talking track:"
Write-Info "  'Personal Dropbox is blocked — not because Dropbox is bad, but"
Write-Info "   because IT does not control data uploaded to personal accounts."
Write-Info "   ZIA distinguishes corporate Dropbox from personal Dropbox.'"
Write-Host ""

Test-CloudApp `
    -Label       "Personal Dropbox (upload)" `
    -Url         "https://www.dropbox.com/upload" `
    -Method      POST `
    -Expected    Block `
    -Description "Personal Dropbox — ZIA blocks based on tenant classification"

Test-CloudApp `
    -Label       "WeTransfer (upload)" `
    -Url         "https://wetransfer.com" `
    -Expected    Block `
    -Description "Consumer file-sharing site — blocked by ZIA Cloud App Control"

Test-CloudApp `
    -Label       "Box.com (personal)" `
    -Url         "https://www.box.com" `
    -Expected    Block `
    -Description "Unapproved file-sharing — blocked by policy"

Pause-Demo

# ---------------------------------------------------------------------------
# Scene 3: Social Media – View Allowed, Post Blocked
# ---------------------------------------------------------------------------
Write-Scene "Scene 3: Social Media – View-Only Policy"
Write-Host ""
Write-Info "Talking track:"
Write-Info "  'Twitter/X is not blocked entirely — employees can read it."
Write-Info "   But posting (HTTP POST) is blocked to prevent data leakage"
Write-Info "   and accidental disclosure of company information.'"
Write-Host ""

Test-CloudApp `
    -Label       "Twitter/X (view)" `
    -Url         "https://twitter.com" `
    -Method      GET `
    -Expected    Allow `
    -Description "Social media GET (view) — allowed by view-only policy"

Test-CloudApp `
    -Label       "Twitter/X (post simulation)" `
    -Url         "https://api.twitter.com/2/tweets" `
    -Method      POST `
    -Expected    Block `
    -Description "Social media POST (upload/post) — blocked by view-only policy"

Test-CloudApp `
    -Label       "Reddit (view)" `
    -Url         "https://www.reddit.com" `
    -Method      GET `
    -Expected    Warn `
    -Description "Social networking — ZIA shows Caution page"

Pause-Demo

# ---------------------------------------------------------------------------
# Scene 4: Cloud App Discovery Summary
# ---------------------------------------------------------------------------
Write-Scene "Scene 4: What to Show in the ZIA Portal"
Write-Host ""
Write-Info "Portal navigation for the customer:"
Write-Host ""
Write-Host "  1. Analytics → Cloud Application Report" -ForegroundColor White
Write-Host "     → Show full inventory of cloud apps discovered" -ForegroundColor Gray
Write-Host "     → Highlight apps the customer may not know employees are using" -ForegroundColor Gray
Write-Host ""
Write-Host "  2. Policy → Cloud Application Control" -ForegroundColor White
Write-Host "     → Walk through sanctioned vs. unsanctioned app rules" -ForegroundColor Gray
Write-Host "     → Show how to add a new app to the blocked list instantly" -ForegroundColor Gray
Write-Host ""
Write-Host "  3. Analytics → Log Explorer" -ForegroundColor White
Write-Host "     → Filter by Application = 'Dropbox'" -ForegroundColor Gray
Write-Host "     → Show ALLOW events for corporate Dropbox, BLOCK for personal" -ForegroundColor Gray
Write-Host ""

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
Write-Sep
Write-Host ""
Write-Host "Demo Complete" -ForegroundColor Green
Write-Host ""
Write-Info "Key talking points:"
Write-Host "  • ZIA knows the difference between corporate and personal app tenants"
Write-Host "  • View-only policies let you allow reading without allowing uploads"
Write-Host "  • Cloud App Report gives IT a full shadow-IT inventory automatically"
Write-Host "  • All events are logged with user identity — full audit trail"
Write-Host ""
