#Requires -Version 5.1
<#
.SYNOPSIS
    Demonstrates ZIA Advanced Threat Protection by attempting downloads of
    known-bad content that ZIA should block.

.DESCRIPTION
    Attempts to access EICAR test files, simulated phishing pages, and
    known-malicious URLs. Each attempt is logged with a BLOCKED or ALLOWED
    result so the presenter can narrate what ZIA is doing.

    Run from a Windows 11 client with ZIA Client Connector installed
    and connected (green tray icon).

.EXAMPLE
    .\scripts\zia\windows\demo_threat_protection.ps1

.EXAMPLE
    .\scripts\zia\windows\demo_threat_protection.ps1 -Quiet
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
function Write-Info   { param($Msg) Write-Host "  [INFO]   $Msg" -ForegroundColor Cyan }
function Write-Scene  { param($Msg) Write-Host "`n=== $Msg ===" -ForegroundColor Blue }
function Write-Sep    { Write-Host ('─' * 60) -ForegroundColor DarkGray }
function Pause-Demo   { if (-not $Quiet) { Read-Host "`n  ↵  Press Enter to continue" | Out-Null } }

# ---------------------------------------------------------------------------
# Helper: attempt a download and check ZIA blocked it
# ---------------------------------------------------------------------------
function Test-ThreatBlock {
    param(
        [string]$Label,
        [string]$Url,
        [string]$Description,
        [ValidateSet('Block','Allow')]
        [string]$Expected = 'Block'
    )

    Write-Host ""
    Write-Info "Testing: $Label"
    Write-Info "URL    : $Url"
    Write-Info "Expect : ZIA should $Expected this"

    $tmpFile = [System.IO.Path]::GetTempFileName()
    try {
        $response = Invoke-WebRequest -Uri $Url -OutFile $tmpFile -TimeoutSec 10 -UseBasicParsing -PassThru
        $code = $response.StatusCode
        $size = (Get-Item $tmpFile).Length
    } catch {
        $code = 0
        $size = 0
    } finally {
        Remove-Item $tmpFile -Force -ErrorAction SilentlyContinue
    }

    if ($Expected -eq 'Block') {
        if ($code -eq 0 -or $code -ge 400 -or $size -eq 0) {
            Write-Block "BLOCKED ✓  $Label (HTTP $code, 0 bytes received)"
        } else {
            Write-Allow "NOT BLOCKED ✗  $Label (HTTP $code, $size bytes) — check ZIA policy"
        }
    } else {
        if ($code -ge 200 -and $code -lt 400) {
            Write-Allow "ALLOWED ✓  $Label (HTTP $code)"
        } else {
            Write-Block "BLOCKED (unexpected) ✗  $Label (HTTP $code)"
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
Write-Host "║     ZIA Advanced Threat Protection Demo              ║" -ForegroundColor Magenta
Write-Host "╚══════════════════════════════════════════════════════╝" -ForegroundColor Magenta
Write-Host ""
Write-Info "This script tests ZIA's ability to detect and block:"
Write-Info "  • Malware downloads (EICAR test files)"
Write-Info "  • Known phishing / malware pages"
Write-Info "  • Risky content categories"
Write-Host ""
Write-Info "ZIA Client Connector must be Connected (green tray icon)."
Write-Host ""
Pause-Demo

# ---------------------------------------------------------------------------
# Scene 1: Verify ZIA is in the path
# ---------------------------------------------------------------------------
Write-Scene "Scene 1: Verify ZIA Is In The Path"
Write-Host ""
Write-Info "Connecting to https://ip.zscaler.com to confirm ZIA routing..."

try {
    $check = Invoke-WebRequest -Uri 'https://ip.zscaler.com' -TimeoutSec 15 -UseBasicParsing
    if ($check.Content -match 'zscaler') {
        Write-Allow "Traffic confirmed routing through ZIA!"
        Write-Host ($check.Content | Select-String -Pattern "(Gateway|ZEN|Location).*" -AllMatches |
            ForEach-Object { $_.Matches.Value } | Select-Object -First 3 | Out-String).Trim()
    } else {
        Write-Info "Response received — check content manually in browser."
    }
} catch {
    Write-Info "Could not reach ip.zscaler.com. Ensure ZIA Client Connector is connected."
}

Pause-Demo

# ---------------------------------------------------------------------------
# Scene 2: EICAR Test File (standard malware test)
# ---------------------------------------------------------------------------
Write-Scene "Scene 2: EICAR Malware Test File"
Write-Host ""
Write-Info "Talking track:"
Write-Info "  'The EICAR file is the industry-standard test for anti-malware."
Write-Info "   ZIA intercepts the download in the cloud — the file never reaches disk.'"
Write-Host ""

Test-ThreatBlock `
    -Label       "EICAR test file (HTTP)" `
    -Url         "http://malware.wicar.org/data/eicar.com" `
    -Expected    Block `
    -Description "Standard EICAR test — ZIA Threat Protection must block this"

Test-ThreatBlock `
    -Label       "EICAR test file (HTTPS)" `
    -Url         "https://malware.wicar.org/data/eicar.com" `
    -Expected    Block `
    -Description "HTTPS EICAR — ZIA SSL inspection must be enabled to catch this"

Test-ThreatBlock `
    -Label       "EICAR in ZIP archive" `
    -Url         "http://malware.wicar.org/data/eicar_com.zip" `
    -Expected    Block `
    -Description "EICAR inside ZIP — tests ZIA's archive inspection capability"

Pause-Demo

# ---------------------------------------------------------------------------
# Scene 3: Known malware / phishing test pages
# ---------------------------------------------------------------------------
Write-Scene "Scene 3: Malware & Phishing Pages"
Write-Host ""
Write-Info "Talking track:"
Write-Info "  'ZIA checks every URL against Zscaler's real-time threat feed."
Write-Info "   The block happens in the cloud before the first TCP packet.'"
Write-Host ""

Test-ThreatBlock `
    -Label       "Malware test page (wicar.org)" `
    -Url         "https://malware.wicar.org" `
    -Expected    Block `
    -Description "Known test malware site — should be categorised as Malware"

Test-ThreatBlock `
    -Label       "Phishing simulation page" `
    -Url         "https://phishing.wicar.org" `
    -Expected    Block `
    -Description "Simulated phishing — categorised as Phishing in ZIA"

Pause-Demo

# ---------------------------------------------------------------------------
# Scene 4: Allowed – legitimate download for contrast
# ---------------------------------------------------------------------------
Write-Scene "Scene 4: Contrast – Allowed Legitimate Download"
Write-Host ""
Write-Info "Talking track:"
Write-Info "  'For comparison — here is a legitimate file download that ZIA allows.'"
Write-Host ""

Test-ThreatBlock `
    -Label       "Zscaler.com (corporate site)" `
    -Url         "https://www.zscaler.com" `
    -Expected    Allow `
    -Description "Legitimate corporate site — allowed by ZIA policy"

Pause-Demo

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
Write-Sep
Write-Host ""
Write-Host "Demo Complete" -ForegroundColor Green
Write-Host ""
Write-Info "Next steps for the customer:"
Write-Host "  1. Open ZIA Admin Portal → Analytics → Threat Insights"
Write-Host "  2. Show the blocked EICAR / malware events with:"
Write-Host "     - User identity"
Write-Host "     - Threat name and category"
Write-Host "     - URL and destination"
Write-Host "     - Action taken (Block)"
Write-Host "  3. Discuss ZIA Cloud Sandbox for unknown file analysis"
Write-Host ""
