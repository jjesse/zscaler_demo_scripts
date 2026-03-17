#Requires -Version 5.1
<#
.SYNOPSIS
    Demonstrates ZPA per-user access control by testing which resources the
    current session (persona) can and cannot reach.

.DESCRIPTION
    This script is the key demo for "Act 1.5 – Granular Per-User Access
    Control" in the ZPA Demo Guide. It runs from the Windows 11 client while
    the ZPA Client Connector is active and the user is logged in as the
    specified persona.

    The four personas map to ZPA access policies as follows:

      ITAdmin    (dept=IT)         WebApps + RDP + FileShare + SSH  [full access]
      Engineer   (dept=Engineering) WebApps + SSH                   [no RDP/SMB]
      Contractor (dept=Contractor)  WebApps only                    [no RDP/SSH/SMB]
      HR         (dept=HR)          Nothing                         [implicit deny]

    Run this script once per persona, each time signed in to ZPA Client as the
    corresponding IdP user. The ALLOWED/BLOCKED results confirm that ZPA is
    enforcing the correct policy for each identity.

.PARAMETER TargetHost
    IP address of the Windows Server running the internal apps.
    Default: 192.168.1.20

.PARAMETER LinuxHost
    IP address of the Ubuntu server running the App Connector.
    Default: 192.168.1.10

.PARAMETER Persona
    The user persona to simulate. Controls expected access results displayed
    alongside actual test results. Choices: ITAdmin, Engineer, Contractor, HR.
    Default: ITAdmin

.PARAMETER ShowDenied
    When specified, runs only the tests that are expected to be BLOCKED for
    this persona. Useful for demonstrating access-denied scenarios.

.PARAMETER LogFile
    Path to write results log. Default: $env:TEMP\zpa_user_access_demo.log

.EXAMPLE
    # Run as bob.jones (IT Admin) – should show full access
    .\demo_user_access.ps1 -Persona ITAdmin

    # Run as carol.white (Contractor) – should show web only, rest blocked
    .\demo_user_access.ps1 -Persona Contractor

    # Run as carol.white showing only her denied resources
    .\demo_user_access.ps1 -Persona Contractor -ShowDenied

    # Run as dave.hr – should show everything blocked
    .\demo_user_access.ps1 -Persona HR
#>

param(
    [string]$TargetHost = "192.168.1.20",
    [string]$LinuxHost  = "192.168.1.10",
    [ValidateSet("ITAdmin","Engineer","Contractor","HR")]
    [string]$Persona    = "ITAdmin",
    [switch]$ShowDenied,
    [string]$LogFile    = "$env:TEMP\zpa_user_access_demo.log"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Continue"

# ── Persona definitions ───────────────────────────────────────────────────────
# Each persona maps to a ZPA access policy rule and expected access matrix.
$PersonaMap = @{
    ITAdmin = @{
        Label       = "IT Admin (bob.jones)"
        Department  = "IT"
        PolicyRule  = "Allow-IT-Admins-Full"
        Description = "Full access: WebApps, RDP, FileShare, SSH"
        AllowedApps = @("WebApps-80","WebApps-443","WebApps-8080","RDP-3389","FileShare-445","SSH-22")
        BlockedApps = @("ShadowApp-9090","DB-1433","DB-5432","DB-6379")
    }
    Engineer = @{
        Label       = "Engineer (alice.smith)"
        Department  = "Engineering"
        PolicyRule  = "Allow-Engineers-WebSSH"
        Description = "Web + SSH only: NO RDP, NO FileShare"
        AllowedApps = @("WebApps-80","WebApps-443","WebApps-8080","SSH-22")
        BlockedApps = @("RDP-3389","FileShare-445","ShadowApp-9090","DB-1433","DB-5432","DB-6379")
    }
    Contractor = @{
        Label       = "Contractor (carol.white)"
        Department  = "Contractor"
        PolicyRule  = "Allow-Contractors-WebOnly"
        Description = "Web portal only: NO RDP, NO SSH, NO FileShare"
        AllowedApps = @("WebApps-80","WebApps-443","WebApps-8080")
        BlockedApps = @("RDP-3389","SSH-22","FileShare-445","ShadowApp-9090","DB-1433","DB-5432","DB-6379")
    }
    HR = @{
        Label       = "HR Analyst (dave.hr)"
        Department  = "HR"
        PolicyRule  = "(none – implicit deny)"
        Description = "No access to any private application"
        AllowedApps = @()
        BlockedApps = @("WebApps-80","WebApps-443","WebApps-8080","RDP-3389","SSH-22","FileShare-445","ShadowApp-9090","DB-1433","DB-5432","DB-6379")
    }
}

# ── App definitions ───────────────────────────────────────────────────────────
$AppDefs = @{
    "WebApps-80"     = @{ Type="HTTP"; Host=$TargetHost; Port=80;    Url="http://$TargetHost/";        Name="Web Portal (HTTP 80)"    }
    "WebApps-443"    = @{ Type="HTTP"; Host=$TargetHost; Port=443;   Url="https://$TargetHost/";       Name="Web Portal (HTTPS 443)"  }
    "WebApps-8080"   = @{ Type="HTTP"; Host=$TargetHost; Port=8080;  Url="http://$TargetHost:8080/";   Name="Alt Web Portal (8080)"   }
    "RDP-3389"       = @{ Type="TCP";  Host=$TargetHost; Port=3389;  Url="";                           Name="RDP (3389)"              }
    "SSH-22"         = @{ Type="TCP";  Host=$LinuxHost;  Port=22;    Url="";                           Name="SSH to Ubuntu (22)"      }
    "FileShare-445"  = @{ Type="SMB";  Host=$TargetHost; Port=445;   Url="\\$TargetHost\LabShare";     Name="SMB File Share"          }
    "ShadowApp-9090" = @{ Type="HTTP"; Host=$TargetHost; Port=9090;  Url="http://$TargetHost:9090/";   Name="Shadow IT App (9090)"    }
    "DB-1433"        = @{ Type="TCP";  Host=$TargetHost; Port=1433;  Url="";                           Name="SQL Server (1433)"       }
    "DB-5432"        = @{ Type="TCP";  Host=$TargetHost; Port=5432;  Url="";                           Name="PostgreSQL (5432)"       }
    "DB-6379"        = @{ Type="TCP";  Host=$TargetHost; Port=6379;  Url="";                           Name="Redis (6379)"            }
}

# ── Colour / logging helpers ──────────────────────────────────────────────────
function Write-Log {
    param([string]$Level, [string]$Message)
    $ts   = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[$ts] [$Level] $Message"
    Add-Content -Path $LogFile -Value $line

    switch ($Level) {
        "PASS"    { Write-Host "  [PASS]    $Message" -ForegroundColor Green  }
        "FAIL"    { Write-Host "  [FAIL]    $Message" -ForegroundColor Red    }
        "BLOCKED" { Write-Host "  [BLOCKED] $Message" -ForegroundColor Green  }
        "ALLOWED" { Write-Host "  [ALLOWED] $Message" -ForegroundColor Red    }
        "INFO"    { Write-Host "  [INFO]    $Message" -ForegroundColor Cyan   }
        "WARN"    { Write-Host "  [WARN]    $Message" -ForegroundColor Yellow }
    }
}

function Write-Banner { param([string]$Text)
    Write-Host ""
    Write-Host ("=" * 68) -ForegroundColor Cyan
    Write-Host "  $Text" -ForegroundColor Cyan
    Write-Host ("=" * 68) -ForegroundColor Cyan
}

function Write-SubBanner { param([string]$Text)
    Write-Host ""
    Write-Host "  ── $Text ──" -ForegroundColor Yellow
}

# ── Test functions ────────────────────────────────────────────────────────────

function Test-HttpApp {
    param([string]$Url, [string]$AppName, [bool]$ShouldBeAllowed)
    try {
        # Lab-only: accept self-signed certificates on the lab HTTPS endpoint.
        # Do NOT use this pattern outside of an isolated test environment.
        try {
            Add-Type -TypeDefinition @"
using System.Net; using System.Security.Cryptography.X509Certificates;
public class TrustAllCerts : ICertificatePolicy {
    public bool CheckValidationResult(ServicePoint sp, X509Certificate cert,
        WebRequest req, int problem) { return true; }
}
"@ -ErrorAction SilentlyContinue
            [System.Net.ServicePointManager]::CertificatePolicy = [TrustAllCerts]::new()
        } catch {}

        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        $r  = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 8 -ErrorAction Stop
        $sw.Stop()

        if ($ShouldBeAllowed) {
            Write-Log "PASS"    "$AppName -> HTTP $($r.StatusCode) in $($sw.ElapsedMilliseconds)ms ✓ (expected ALLOW)"
            return $true
        } else {
            Write-Log "ALLOWED" "$AppName -> HTTP $($r.StatusCode) UNEXPECTED – should be blocked!"
            return $false
        }
    } catch {
        if ($ShouldBeAllowed) {
            Write-Log "FAIL"    "$AppName -> $($_.Exception.GetType().Name) (expected ALLOW but got BLOCKED)"
            return $false
        } else {
            Write-Log "BLOCKED" "$AppName -> blocked as expected ✓"
            return $true
        }
    }
}

function Test-TcpApp {
    param([string]$Hostname, [int]$Port, [string]$AppName, [bool]$ShouldBeAllowed)
    $tcp = $null
    try {
        $tcp    = [System.Net.Sockets.TcpClient]::new()
        $result = $tcp.BeginConnect($Hostname, $Port, $null, $null)
        $open   = $result.AsyncWaitHandle.WaitOne(5000)

        if ($open) {
            if ($ShouldBeAllowed) {
                Write-Log "PASS"    "$AppName -> TCP ${Hostname}:${Port} open ✓ (expected ALLOW)"
                return $true
            } else {
                Write-Log "ALLOWED" "$AppName -> TCP ${Hostname}:${Port} UNEXPECTED – should be blocked!"
                return $false
            }
        } else {
            if ($ShouldBeAllowed) {
                Write-Log "FAIL"    "$AppName -> TCP ${Hostname}:${Port} timed out (expected ALLOW but got BLOCKED)"
                return $false
            } else {
                Write-Log "BLOCKED" "$AppName -> blocked as expected ✓"
                return $true
            }
        }
    } catch {
        if ($ShouldBeAllowed) {
            Write-Log "FAIL"    "$AppName -> $($_.Exception.Message) (expected ALLOW)"
            return $false
        } else {
            Write-Log "BLOCKED" "$AppName -> blocked as expected ✓"
            return $true
        }
    } finally {
        if ($null -ne $tcp) { $tcp.Dispose() }
    }
}

function Test-SmbApp {
    param([string]$SharePath, [string]$AppName, [bool]$ShouldBeAllowed)
    try {
        $items = Get-ChildItem -Path $SharePath -ErrorAction Stop
        if ($ShouldBeAllowed) {
            Write-Log "PASS"    "$AppName -> Listed $($items.Count) item(s) ✓ (expected ALLOW)"
            return $true
        } else {
            Write-Log "ALLOWED" "$AppName -> $SharePath UNEXPECTED – should be blocked!"
            return $false
        }
    } catch {
        if ($ShouldBeAllowed) {
            Write-Log "FAIL"    "$AppName -> $($_.Exception.Message) (expected ALLOW)"
            return $false
        } else {
            Write-Log "BLOCKED" "$AppName -> blocked as expected ✓"
            return $true
        }
    }
}

function Invoke-AppTest {
    param([string]$AppKey, [bool]$ShouldBeAllowed)
    $app = $AppDefs[$AppKey]
    if (-not $app) {
        Write-Log "WARN" "Unknown app key: $AppKey"
        return $false
    }

    switch ($app.Type) {
        "HTTP" { return Test-HttpApp -Url $app.Url -AppName $app.Name -ShouldBeAllowed $ShouldBeAllowed }
        "TCP"  { return Test-TcpApp -Hostname $app.Host -Port $app.Port -AppName $app.Name -ShouldBeAllowed $ShouldBeAllowed }
        "SMB"  { return Test-SmbApp -SharePath $app.Url -AppName $app.Name -ShouldBeAllowed $ShouldBeAllowed }
    }
    return $false
}

# ── Main ──────────────────────────────────────────────────────────────────────

$p = $PersonaMap[$Persona]

Write-Banner "ZPA Per-User Access Demo"
Write-Host "  Persona    : $($p.Label)" -ForegroundColor White
Write-Host "  Department : $($p.Department)" -ForegroundColor White
Write-Host "  Policy     : $($p.PolicyRule)" -ForegroundColor White
Write-Host "  Expected   : $($p.Description)" -ForegroundColor White
Write-Host ""
Write-Host "  GREEN [PASS]    = allowed as expected" -ForegroundColor Green
Write-Host "  GREEN [BLOCKED] = blocked as expected" -ForegroundColor Green
Write-Host "  RED   [FAIL]    = should be allowed but was blocked (check policy)" -ForegroundColor Red
Write-Host "  RED   [ALLOWED] = should be blocked but was allowed (check policy)" -ForegroundColor Red
Write-Host ""

$passCount = 0
$failCount = 0

# ── Allowed resources ─────────────────────────────────────────────────────────
if (-not $ShowDenied -and $p.AllowedApps.Count -gt 0) {
    Write-SubBanner "Resources this persona SHOULD be able to reach"
    foreach ($appKey in $p.AllowedApps) {
        $ok = Invoke-AppTest -AppKey $appKey -ShouldBeAllowed $true
        if ($ok) { $passCount++ } else { $failCount++ }
    }
}

# ── Blocked resources ─────────────────────────────────────────────────────────
if ($p.BlockedApps.Count -gt 0) {
    Write-SubBanner "Resources this persona should NOT be able to reach"
    foreach ($appKey in $p.BlockedApps) {
        $ok = Invoke-AppTest -AppKey $appKey -ShouldBeAllowed $false
        if ($ok) { $passCount++ } else { $failCount++ }
    }
}

# ── Summary ───────────────────────────────────────────────────────────────────
Write-Host ""
Write-Banner "Access Demo Complete – $($p.Label)"

Write-Host ""
Write-Host "  Persona    : $($p.Label)" -ForegroundColor White
Write-Host "  Expected   : $($p.Description)" -ForegroundColor White
Write-Host ""
Write-Host "  Tests matching policy : $passCount" -ForegroundColor Green
Write-Host "  Tests NOT matching    : $failCount" -ForegroundColor $(if ($failCount -gt 0) { "Red" } else { "Green" })
Write-Host ""
Write-Host "  Full log   : $LogFile" -ForegroundColor White
Write-Host ""

if ($failCount -gt 0) {
    Write-Host "  ACTION REQUIRED: $failCount test(s) did not match expected policy." -ForegroundColor Red
    Write-Host "  Open ZPA Admin Portal → Policy → Policy Simulation to debug." -ForegroundColor Red
    Write-Host ""
}

Write-Host "  DEMO TIP: Compare this output across personas to show customers" -ForegroundColor Cyan
Write-Host "  how ZPA enforces granular, identity-aware access control." -ForegroundColor Cyan
Write-Host "  Suggested pairs for maximum impact:" -ForegroundColor Cyan
Write-Host "    • ITAdmin vs Contractor  (full access vs web-only)" -ForegroundColor Cyan
Write-Host "    • Engineer vs HR         (partial vs zero access)" -ForegroundColor Cyan
Write-Host ""
