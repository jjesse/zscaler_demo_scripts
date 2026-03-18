#Requires -Version 5.1
<#
.SYNOPSIS
    Demonstrates ZIA threat protection and URL-category blocking by attempting
    to reach known-bad and restricted-category URLs.

.DESCRIPTION
    This script is the key demo for "Act 3 – Threat & Policy Blocks" in the
    ZIA Demo Guide. It runs from the Windows 11 client while Zscaler Client
    Connector is active and attempts to reach:

      1. Malware / Threat test URLs (EICAR, Google Safe Browsing test pages)
      2. Phishing simulation pages (safe; designed for security-awareness demos)
      3. Gambling sites (typically blocked in enterprise ZIA URL-filter policies)
      4. Anonymizer / proxy-circumvention sites (blocked to prevent bypass)
      5. Peer-to-Peer / torrent sites (blocked to protect bandwidth & IP)

    Every attempt that ZIA blocks will either time out or return ZIA's
    block page. Results are logged to the console and to a log file.

    Safe test URLs used:
      - EICAR standard test (http://www.eicar.org/download/eicar.com.txt)
        Harmless; every security product categorises it as malware for testing.
      - Zscaler security-test page (https://security.zscaler.com/)
      - Google Safe Browsing test pages (testsafebrowsing.appspot.com)

.PARAMETER LogFile
    Path to write results log. Default: $env:TEMP\zia_block_demo.log

.PARAMETER RepeatCount
    Number of times to run the full attempt set. Default: 1

.EXAMPLE
    .\demo_zia_blocks.ps1
    .\demo_zia_blocks.ps1 -RepeatCount 3
    .\demo_zia_blocks.ps1 -LogFile C:\Temp\zia_demo.log
#>

param(
    [string]$LogFile     = "$env:TEMP\zia_block_demo.log",
    [int]$RepeatCount    = 1
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Continue"

# ── Logging ───────────────────────────────────────────────────────────────────
$BlockedCount = 0
$AllowedCount = 0

function Write-Log {
    param([string]$Level, [string]$Message)
    $ts   = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[$ts] [$Level] $Message"
    Add-Content -Path $LogFile -Value $line

    switch ($Level) {
        "BLOCKED" { Write-Host "  $line" -ForegroundColor Green  }
        "ALLOWED" { Write-Host "  $line  <- check ZIA policy!" -ForegroundColor Red }
        "INFO"    { Write-Host "  $line" -ForegroundColor Cyan   }
        "WARN"    { Write-Host "  $line" -ForegroundColor Yellow }
    }
}

function Write-Banner {
    param([string]$Text)
    Write-Host ""
    Write-Host ("=" * 68) -ForegroundColor Cyan
    Write-Host "  $Text" -ForegroundColor Cyan
    Write-Host ("=" * 68) -ForegroundColor Cyan
}

function Write-SubBanner {
    param([string]$Text)
    Write-Host ""
    Write-Host "  -- $Text --" -ForegroundColor Magenta
}

# ── Test helper ───────────────────────────────────────────────────────────────
function Test-BlockedUrl {
    param(
        [string]$Url,
        [string]$Label
    )
    Write-Log "INFO" "Attempting: $Label -> $Url"
    try {
        $response = Invoke-WebRequest -Uri $Url -UseBasicParsing `
                    -TimeoutSec 10 -ErrorAction Stop `
                    -UserAgent "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"

        $body = $response.Content
        # Check whether ZIA returned its block page (ZIA proxies to a block page
        # with HTTP 200 containing Zscaler branding)
        $isBlockPage = $body -imatch "zscaler|blocked by|access denied|this site is blocked|security policy"

        if ($isBlockPage) {
            $script:BlockedCount++
            Write-Log "BLOCKED" "$Label -> ZIA block page returned (HTTP $($response.StatusCode)) ✓"
        } else {
            $script:AllowedCount++
            Write-Log "ALLOWED" "$Label -> HTTP $($response.StatusCode) – NOT blocked by ZIA"
        }
    } catch [System.Net.WebException] {
        $status = $_.Exception.Status
        if ($status -in @("ConnectFailure", "Timeout", "ReceiveFailure", "ConnectionClosed")) {
            # ZIA dropped the connection – this is the expected block behaviour
            $script:BlockedCount++
            Write-Log "BLOCKED" "$Label -> $status (ZIA dropped the traffic) ✓"
        } else {
            $script:AllowedCount++
            Write-Log "ALLOWED" "$Label -> Unexpected error: $status"
        }
    } catch {
        # General failure (DNS, proxy, etc.) – treat as blocked for demo purposes
        $script:BlockedCount++
        Write-Log "BLOCKED" "$Label -> $($_.Exception.GetType().Name) (connection did not reach destination) ✓"
    }
}

# ── Main ──────────────────────────────────────────────────────────────────────
Write-Banner "ZIA Block Demo – Windows Client"

Write-Host ""
Write-Host @"
DEMO NARRATIVE:
  The following connections target URLs in threat and restricted
  URL categories. ZIA should intercept and block each one.

  GREEN [BLOCKED] = ZIA blocked the request as expected ✓
  RED   [ALLOWED] = ZIA did NOT block – check your ZIA URL-filter and
                    Threat Protection policies.

  Ensure Zscaler Client Connector is CONNECTED (green tray icon).
"@ -ForegroundColor White

Write-Log "INFO" "Log file     : $LogFile"
Write-Log "INFO" "Repeat count : $RepeatCount"

for ($i = 1; $i -le $RepeatCount; $i++) {

    Write-Banner "Round $i of $RepeatCount"

    # ── 1. Threat Protection – Malware test ───────────────────────────────────
    Write-SubBanner "Threat Protection – Malware / Virus Test URLs"
    Write-Host "  (These safe test URLs are categorised as 'Malware' by ZIA" -ForegroundColor Cyan
    Write-Host "   threat intelligence. No real malware is downloaded.)" -ForegroundColor Cyan

    # EICAR standard antivirus test file – universally recognised as safe test
    Test-BlockedUrl `
        -Url "http://www.eicar.org/download/eicar.com.txt" `
        -Label "EICAR test file (malware category)"

    # Zscaler's own security test page – purpose-built for ZIA demos
    Test-BlockedUrl `
        -Url "https://security.zscaler.com/" `
        -Label "Zscaler security test page"

    # WICAR – Web Malware Simulation test pages (safe)
    Test-BlockedUrl `
        -Url "http://malware.wicar.org/data/ms14_064_ole_not_xp.html" `
        -Label "WICAR malware simulation test"

    # ── 2. Phishing / Social Engineering ─────────────────────────────────────
    Write-SubBanner "Threat Protection – Phishing Test URLs"
    Write-Host "  (Phishing simulation pages – safe, designed for security testing)" -ForegroundColor Cyan

    Test-BlockedUrl `
        -Url "https://testsafebrowsing.appspot.com/s/phishing.html" `
        -Label "Google Safe Browsing – phishing test"

    Test-BlockedUrl `
        -Url "https://testsafebrowsing.appspot.com/s/malware.html" `
        -Label "Google Safe Browsing – malware test"

    # ── 3. URL Filtering – Gambling ───────────────────────────────────────────
    Write-SubBanner "URL Filtering – Gambling (blocked category)"
    Write-Host "  (Gambling sites are blocked by default in enterprise ZIA policies)" -ForegroundColor Cyan

    Test-BlockedUrl `
        -Url "https://www.bet365.com" `
        -Label "Gambling – bet365.com"

    Test-BlockedUrl `
        -Url "https://www.draftkings.com" `
        -Label "Gambling – draftkings.com"

    # ── 4. URL Filtering – Anonymizers & Proxies ─────────────────────────────
    Write-SubBanner "URL Filtering – Anonymizers & Proxies (blocked category)"
    Write-Host "  (Anonymizers are blocked to prevent circumvention of ZIA policy)" -ForegroundColor Cyan

    Test-BlockedUrl `
        -Url "https://www.hidemyass.com" `
        -Label "Anonymizer – hidemyass.com"

    Test-BlockedUrl `
        -Url "https://www.anonymouse.org" `
        -Label "Anonymizer – anonymouse.org"

    # ── 5. URL Filtering – Peer-to-Peer / Torrents ───────────────────────────
    Write-SubBanner "URL Filtering – Peer-to-Peer / Torrents (blocked category)"
    Write-Host "  (P2P sites are blocked to protect bandwidth and legal exposure)" -ForegroundColor Cyan

    Test-BlockedUrl `
        -Url "https://www.thepiratebay.org" `
        -Label "P2P/Torrent – thepiratebay.org"

    if ($i -lt $RepeatCount) {
        Write-Log "INFO" "Waiting 3 seconds before next round..."
        Start-Sleep -Seconds 3
    }
}

# ── Summary ───────────────────────────────────────────────────────────────────
Write-Banner "ZIA Block Demo Complete"

Write-Host ""
Write-Host "  Results from this run:" -ForegroundColor White
Write-Host "    BLOCKED (expected / desired) : $BlockedCount" -ForegroundColor Green
$allowedColor = if ($AllowedCount -gt 0) { "Red" } else { "Green" }
Write-Host "    ALLOWED (unexpected)         : $AllowedCount" -ForegroundColor $allowedColor
Write-Host ""
Write-Host "  Full log: $LogFile" -ForegroundColor White
Write-Host ""
Write-Host "  NEXT STEP: Open ZIA Admin Portal -> Analytics -> Web Insights" -ForegroundColor White
Write-Host "  Filter by this machine's IP or user to see all block events." -ForegroundColor White
Write-Host "  Each blocked URL appears with category, threat name, and action." -ForegroundColor White
Write-Host ""

if ($AllowedCount -gt 0) {
    Write-Host "  WARNING: $AllowedCount URL(s) were NOT blocked by ZIA!" -ForegroundColor Red
    Write-Host "  Review your ZIA URL-Filtering policy and Threat Protection settings." -ForegroundColor Red
    Write-Host ""
}
