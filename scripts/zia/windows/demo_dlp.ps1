#Requires -Version 5.1
<#
.SYNOPSIS
    Demonstrates ZIA Data Loss Prevention (DLP) by attempting to upload
    sensitive data patterns that ZIA should detect and block.

.DESCRIPTION
    Simulates common DLP scenarios:
    - Credit card number upload (blocked)
    - Social Security Number upload (blocked / logged)
    - Confidential document upload (blocked)
    - Benign file upload (allowed)

    Run from a Windows 11 client with ZIA Client Connector installed
    and connected (green tray icon).

.EXAMPLE
    .\scripts\zia\windows\demo_dlp.ps1

.EXAMPLE
    .\scripts\zia\windows\demo_dlp.ps1 -Quiet
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
# DEMO DATA NOTICE
# All values below are universally-known TEST patterns used by the security
# industry for DLP demonstration and QA purposes. They are NOT real data:
#
#   Credit card : 4111-1111-1111-1111  — Visa test number (Luhn-valid, never
#                 issued to a cardholder; listed in every payment gateway SDK)
#   SSN         : 078-05-1120          — The "Woolworth Wallet" SSN, invalidated
#                 by the SSA in 1938 and used in textbooks ever since
#
# These values are safe to include in demo scripts. ZIA DLP should detect them
# because it matches patterns, not whether the number is "live".
# ---------------------------------------------------------------------------
$FakeCreditCard  = "4111111111111111"
$FakeSSN         = "078-05-1120"
$FakeCCFormatted = "4111-1111-1111-1111"

# ---------------------------------------------------------------------------
# Helper: create a temp file with sensitive content and attempt upload
# ---------------------------------------------------------------------------
function Test-DLPUpload {
    param(
        [string]$Label,
        [string]$FileContent,
        [string]$TargetUrl,
        [string]$Description,
        [ValidateSet('Allow','Block')]
        [string]$Expected
    )

    # Write content to a temp file
    $tmpFile = [System.IO.Path]::GetTempFileName()
    [System.IO.File]::WriteAllText($tmpFile, $FileContent)

    Write-Host ""
    Write-Info "DLP Test : $Label"
    Write-Info "Target   : $TargetUrl"
    Write-Info "Expect   : ZIA should $Expected this upload"

    try {
        # Simulate file upload via multipart POST
        $boundary = [System.Guid]::NewGuid().ToString()
        $fileBytes = [System.IO.File]::ReadAllBytes($tmpFile)
        $fileName  = [System.IO.Path]::GetFileName($tmpFile) + ".txt"

        $bodyParts = @(
            "--$boundary"
            "Content-Disposition: form-data; name=`"file`"; filename=`"$fileName`""
            "Content-Type: text/plain"
            ""
            [System.Text.Encoding]::UTF8.GetString($fileBytes)
            "--$boundary--"
        )
        $body = $bodyParts -join "`r`n"
        $bodyBytes = [System.Text.Encoding]::UTF8.GetBytes($body)

        $response = Invoke-WebRequest `
            -Uri $TargetUrl `
            -Method POST `
            -Body $bodyBytes `
            -ContentType "multipart/form-data; boundary=$boundary" `
            -TimeoutSec 10 `
            -UseBasicParsing
        $code = $response.StatusCode
    } catch {
        $code = 0
    } finally {
        Remove-Item $tmpFile -Force -ErrorAction SilentlyContinue
    }

    if ($Expected -eq 'Block') {
        if ($code -eq 0 -or $code -ge 400) {
            Write-Block "BLOCKED ✓  $Label — ZIA DLP intercepted the upload"
        } else {
            Write-Info "NOT BLOCKED (HTTP $code) — verify DLP dictionary and rule are active"
        }
    } else {
        if ($code -ge 200 -and $code -lt 400) {
            Write-Allow "ALLOWED ✓  $Label (HTTP $code)"
        } else {
            Write-Info  "Upload failed (HTTP $code) — target site may be unreachable"
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
Write-Host "║     ZIA Data Loss Prevention (DLP) Demo              ║" -ForegroundColor Magenta
Write-Host "╚══════════════════════════════════════════════════════╝" -ForegroundColor Magenta
Write-Host ""
Write-Info "This script demonstrates ZIA DLP by attempting to upload"
Write-Info "files containing sensitive data patterns."
Write-Host ""
Write-Info "Sensitive data used is FAKE (Luhn-valid test numbers, textbook SSN)."
Write-Info "It is safe to use in demos but ZIA DLP should still detect it."
Write-Host ""
Write-Info "ZIA Client Connector must be Connected (green tray icon)."
Write-Host ""
Pause-Demo

# ---------------------------------------------------------------------------
# Scene 1: Credit Card Number Upload
# ---------------------------------------------------------------------------
Write-Scene "Scene 1: Credit Card Number Upload (Blocked)"
Write-Host ""
Write-Info "Talking track:"
Write-Info "  'An employee is trying to copy a spreadsheet with customer credit"
Write-Info "   card numbers to their personal file storage. ZIA catches it.'"
Write-Host ""

$CCContent = @"
Customer Payment Data Export
Date: $(Get-Date -Format 'yyyy-MM-dd')

Name,Card Number,Expiry,CVV
John Doe,$FakeCCFormatted,12/26,123
Jane Smith,5500-0000-0000-0004,11/25,456
Bob Jones,3714 496353 98431,09/24,789
"@

Test-DLPUpload `
    -Label       "Credit card spreadsheet → personal cloud storage" `
    -FileContent $CCContent `
    -TargetUrl   "https://www.dropbox.com/upload" `
    -Expected    Block `
    -Description "ZIA DLP dictionary: Credit Cards (Luhn-valid numbers detected)"

Pause-Demo

# ---------------------------------------------------------------------------
# Scene 2: Social Security Number Upload
# ---------------------------------------------------------------------------
Write-Scene "Scene 2: SSN / PII Upload (Blocked)"
Write-Host ""
Write-Info "Talking track:"
Write-Info "  'HR is trying to email a list of employee SSNs. ZIA blocks the"
Write-Info "   upload and alerts the security team — with the user's identity.'"
Write-Host ""

$SSNContent = @"
HR Employee Data – CONFIDENTIAL
Generated: $(Get-Date -Format 'yyyy-MM-dd')

Employee,SSN,DOB
Alice Smith,$FakeSSN,1985-03-12
Bob Jones,987-65-4321,1978-07-04
Carol White,219-09-9999,1990-11-30
"@

Test-DLPUpload `
    -Label       "Employee SSN list → webmail attachment" `
    -FileContent $SSNContent `
    -TargetUrl   "https://mail.google.com/mail/u/0/upload" `
    -Expected    Block `
    -Description "ZIA DLP dictionary: US Social Security Numbers"

Pause-Demo

# ---------------------------------------------------------------------------
# Scene 3: Confidential Document Upload
# ---------------------------------------------------------------------------
Write-Scene "Scene 3: Confidential Document Upload (Blocked)"
Write-Host ""
Write-Info "Talking track:"
Write-Info "  'This document is watermarked CONFIDENTIAL. ZIA's content"
Write-Info "   inspection catches the keyword even inside a text body.'"
Write-Host ""

$ConfContent = @"
CONFIDENTIAL – FOR INTERNAL USE ONLY
Project Titan – M&A Roadmap Q3 2026

This document contains sensitive merger and acquisition details.
Do not distribute outside of the executive leadership team.

Target Company: Acme Corp
Valuation: USD 2.4 billion
Expected Close: Q4 2026
"@

Test-DLPUpload `
    -Label       "Confidential M&A document → file-sharing site" `
    -FileContent $ConfContent `
    -TargetUrl   "https://wetransfer.com" `
    -Expected    Block `
    -Description "ZIA DLP: custom dictionary keyword 'CONFIDENTIAL'"

Pause-Demo

# ---------------------------------------------------------------------------
# Scene 4: Benign File Upload (Allowed – for contrast)
# ---------------------------------------------------------------------------
Write-Scene "Scene 4: Benign File Upload (Allowed — Contrast)"
Write-Host ""
Write-Info "Talking track:"
Write-Info "  'For contrast — a regular text file with no sensitive data"
Write-Info "   uploads normally. DLP only fires when it detects a match.'"
Write-Host ""

$BenignContent = @"
Demo Notes – $(Get-Date -Format 'yyyy-MM-dd')
Meeting summary from ZIA demo session.
No sensitive data in this file.
"@

Test-DLPUpload `
    -Label       "Benign meeting notes → file storage" `
    -FileContent $BenignContent `
    -TargetUrl   "https://onedrive.live.com" `
    -Expected    Allow `
    -Description "No sensitive patterns — ZIA DLP allows the upload"

Pause-Demo

# ---------------------------------------------------------------------------
# Scene 5: What to Show in the Portal
# ---------------------------------------------------------------------------
Write-Scene "Scene 5: What to Show in the ZIA Portal"
Write-Host ""
Write-Info "Portal navigation for the customer:"
Write-Host ""
Write-Host "  1. Analytics → DLP Incident Reports" -ForegroundColor White
Write-Host "     → Show each blocked event with:" -ForegroundColor Gray
Write-Host "        - User identity (who tried to upload)" -ForegroundColor Gray
Write-Host "        - Matched DLP dictionary (Credit Cards, SSN)" -ForegroundColor Gray
Write-Host "        - Destination URL / application" -ForegroundColor Gray
Write-Host "        - Snippet of matched content" -ForegroundColor Gray
Write-Host ""
Write-Host "  2. Policy → Data Loss Prevention → Rules" -ForegroundColor White
Write-Host "     → Walk through the Block-CC-Upload and Warn-SSN-Upload rules" -ForegroundColor Gray
Write-Host "     → Show how to add a custom dictionary for company-specific data" -ForegroundColor Gray
Write-Host ""
Write-Host "  3. Analytics → Log Explorer" -ForegroundColor White
Write-Host "     → Filter action = DLP_BLOCK" -ForegroundColor Gray
Write-Host "     → Show the full audit trail across all users" -ForegroundColor Gray
Write-Host ""

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
Write-Sep
Write-Host ""
Write-Host "Demo Complete" -ForegroundColor Green
Write-Host ""
Write-Info "Key talking points:"
Write-Host "  • ZIA DLP inspects all HTTPS traffic — no blind spots"
Write-Host "  • 100+ built-in dictionaries for PCI, HIPAA, GDPR data types"
Write-Host "  • Custom dictionaries for company-specific intellectual property"
Write-Host "  • Every DLP event logged with user identity — full compliance audit trail"
Write-Host "  • No on-prem DLP hardware or agents required"
Write-Host ""
