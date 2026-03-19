#Requires -Version 5.1
<#
.SYNOPSIS
    Simulates good and poor Zscaler Digital Experience (ZDX) scores on a
    Windows endpoint so the ZDX dashboard and score-trend graphs update live
    during a customer demo.

.DESCRIPTION
    ZDX continuously probes network path quality, DNS resolution, TCP connect
    time, TLS handshake time, and HTTP response time for monitored applications,
    then combines those signals with device-health metrics (CPU, RAM, Wi-Fi)
    into a ZDX Score (0-100).

    This script drives those same metrics into "good" or "poor" territory so
    the audience can see the ZDX score change live in the portal:

      Good scenario   – lightweight probes, low latency, clean results.
                        Score typically stays >= 80 (green).

      Poor scenario   – saturates CPU/RAM, runs large parallel downloads to
                        introduce congestion, and shows the resulting high
                        latency / packet-loss in probe output.
                        Score typically drops to < 40 (red).

      Restore scenario – terminates background load jobs and restores the
                         machine to a healthy state.

    NOTE: This script only measures and reports metrics that ZDX would observe.
          The *actual* ZDX score update in the portal depends on the ZDX probe
          cycle configured for your tenant (typically 1-5 minutes).

.PARAMETER Scenario
    Which scenario to run: Good | Poor | Restore

.PARAMETER Iterations
    Number of probe rounds to run (Good scenario). 0 = run until Ctrl-C.
    Default: 0

.PARAMETER Interval
    Seconds between probe rounds (Good scenario). Default: 30

.PARAMETER Verbose
    Show detailed per-probe output.

.EXAMPLE
    # Baseline good experience – run before the meeting to populate history
    .\demo_zdx_scores.ps1 -Scenario Good

    # Degrade experience live during the demo
    .\demo_zdx_scores.ps1 -Scenario Poor

    # Restore healthy state after the demo
    .\demo_zdx_scores.ps1 -Scenario Restore
#>

param(
    [ValidateSet('Good','Poor','Restore')]
    [string]$Scenario  = 'Good',
    [int]   $Iterations = 0,
    [int]   $Interval   = 30
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Continue"

# ── Colour helpers ────────────────────────────────────────────────────────────
function Write-Good    { param([string]$msg) Write-Host "  [GOOD]   $msg" -ForegroundColor Green }
function Write-Poor    { param([string]$msg) Write-Host "  [POOR]   $msg" -ForegroundColor Red }
function Write-Info    { param([string]$msg) Write-Host "  [INFO]   $msg" -ForegroundColor Cyan }
function Write-Warn    { param([string]$msg) Write-Host "  [WARN]   $msg" -ForegroundColor Yellow }
function Write-Section { param([string]$msg) Write-Host "`n  --- $msg ---" -ForegroundColor Magenta }
function Get-Ts        { Get-Date -Format "yyyy-MM-dd HH:mm:ss" }

# ── Monitored application endpoints (mirrors typical ZDX probe targets) ───────
$AppProbes = [ordered]@{
    "Microsoft 365 (Exchange)" = "https://outlook.office365.com"
    "Microsoft Teams"          = "https://teams.microsoft.com"
    "Zoom"                     = "https://zoom.us"
    "Salesforce"               = "https://login.salesforce.com"
    "Google Workspace"         = "https://workspace.google.com"
}

# ── Probe a single application endpoint ──────────────────────────────────────
function Invoke-ZdxProbe {
    param(
        [string]$AppName,
        [string]$Url,
        [switch]$ShowDetail
    )

    $uri = [System.Uri]$Url
    $host_ = $uri.Host
    $port  = if ($uri.Port -gt 0) { $uri.Port } else { 443 }

    # DNS resolution
    $dnsMs = 9999
    try {
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        [System.Net.Dns]::GetHostAddresses($host_) | Out-Null
        $sw.Stop()
        $dnsMs = $sw.ElapsedMilliseconds
    } catch {
        $dnsMs = 9999
    }

    # TCP connect
    $tcpMs = 9999
    try {
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        $tcp = New-Object System.Net.Sockets.TcpClient
        $async = $tcp.BeginConnect($host_, $port, $null, $null)
        $waited = $async.AsyncWaitHandle.WaitOne(5000, $false)
        $sw.Stop()
        if ($waited) {
            $tcp.EndConnect($async)
            $tcpMs = $sw.ElapsedMilliseconds
        }
        $tcp.Close()
    } catch {
        $tcpMs = 9999
    }

    # HTTP response (includes TLS handshake + server time)
    $httpMs    = 9999
    $statusCode = 0
    try {
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        $resp = Invoke-WebRequest -Uri $Url -UseBasicParsing `
                    -TimeoutSec 10 -ErrorAction Stop `
                    -UserAgent "ZDX-Demo/1.0 (Windows)"
        $sw.Stop()
        $httpMs     = $sw.ElapsedMilliseconds
        $statusCode = $resp.StatusCode
    } catch [System.Net.WebException] {
        $sw.Stop()
        $httpMs = $sw.ElapsedMilliseconds
        $statusCode = [int]$_.Exception.Response.StatusCode
    } catch {
        $httpMs = 9999
    }

    # Estimate ZDX score contribution from this probe
    $score = 100
    if ($dnsMs -gt 500)  { $score -= 30 }
    elseif ($dnsMs -gt 100) { $score -= 10 }
    if ($tcpMs -gt 800)  { $score -= 30 }
    elseif ($tcpMs -gt 200) { $score -= 10 }
    if ($httpMs -gt 2000) { $score -= 30 }
    elseif ($httpMs -gt 500) { $score -= 10 }
    $score = [Math]::Max(0, $score)

    $scoreLabel = switch ($score) {
        { $_ -ge 80 } { "GOOD   ($score)" }
        { $_ -ge 60 } { "FAIR   ($score)" }
        { $_ -ge 40 } { "DEGRADED ($score)" }
        default        { "POOR   ($score)" }
    }
    $scoreColor = switch ($score) {
        { $_ -ge 80 } { "Green" }
        { $_ -ge 60 } { "Yellow" }
        { $_ -ge 40 } { "DarkYellow" }
        default        { "Red" }
    }

    Write-Host ("  {0,-35} DNS:{1,5}ms  TCP:{2,5}ms  HTTP:{3,6}ms  Score: {4}" -f `
        $AppName, $dnsMs, $tcpMs, $httpMs, $scoreLabel) `
        -ForegroundColor $scoreColor
}

# ── Device health snapshot ────────────────────────────────────────────────────
function Show-DeviceHealth {
    Write-Section "Device Health (ZDX Device Score inputs)"

    # CPU
    $cpu = (Get-CimInstance -ClassName Win32_Processor |
            Measure-Object -Property LoadPercentage -Average).Average
    $cpuColor = if ($cpu -lt 60) { "Green" } elseif ($cpu -lt 80) { "Yellow" } else { "Red" }
    Write-Host ("  CPU Usage       : {0,3}%" -f [int]$cpu) -ForegroundColor $cpuColor

    # RAM
    $os = Get-CimInstance -ClassName Win32_OperatingSystem
    $ramUsedPct = [Math]::Round(($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) /
                   $os.TotalVisibleMemorySize * 100, 1)
    $ramColor = if ($ramUsedPct -lt 70) { "Green" } elseif ($ramUsedPct -lt 85) { "Yellow" } else { "Red" }
    Write-Host ("  RAM Usage       : {0,5}%" -f $ramUsedPct) -ForegroundColor $ramColor

    # Wi-Fi signal (if available)
    try {
        $wifiSignal = netsh wlan show interfaces 2>$null |
            Select-String "Signal" | Select-Object -First 1 |
            ForEach-Object { ($_ -replace '.*:\s*','').Trim() }
        if ($wifiSignal) {
            Write-Host "  Wi-Fi Signal    : $wifiSignal" -ForegroundColor Cyan
        } else {
            Write-Host "  Wi-Fi Signal    : (wired / not available)" -ForegroundColor Gray
        }
    } catch {
        Write-Host "  Wi-Fi Signal    : (not available)" -ForegroundColor Gray
    }

    # ZCC status
    $zccRunning = Get-Process -Name "ZSAService","ZSATunnel","ZSAUpdater" `
                  -ErrorAction SilentlyContinue | Measure-Object | Select-Object -ExpandProperty Count
    $zccColor = if ($zccRunning -gt 0) { "Green" } else { "Red" }
    Write-Host ("  ZCC Processes   : {0} running" -f $zccRunning) -ForegroundColor $zccColor
}

# ── Packet-loss probe (ICMP ping to well-known DNS servers) ──────────────────
function Show-PacketLoss {
    param([string[]]$Targets = @("8.8.8.8","1.1.1.1","208.67.222.222"))

    Write-Section "Packet Loss & Latency (ZDX Network Score inputs)"
    foreach ($target in $Targets) {
        $pingResult = Test-Connection -ComputerName $target -Count 10 `
                      -ErrorAction SilentlyContinue
        if ($pingResult) {
            $sent     = 10
            $received = ($pingResult | Measure-Object).Count
            $lost     = $sent - $received
            $lossPct  = [Math]::Round($lost / $sent * 100, 0)
            $avgMs    = ($pingResult | Measure-Object -Property ResponseTime -Average).Average
            $avgMs    = [Math]::Round($avgMs, 0)

            $color = if ($lossPct -eq 0 -and $avgMs -lt 50) { "Green" }
                     elseif ($lossPct -le 2 -and $avgMs -lt 150) { "Yellow" }
                     else { "Red" }

            Write-Host ("  {0,-15}  Avg:{1,5}ms  Loss:{2,3}%" -f $target, $avgMs, $lossPct) `
                -ForegroundColor $color
        } else {
            Write-Host "  $target`t → no response" -ForegroundColor Red
        }
    }
}

# ── Good scenario ─────────────────────────────────────────────────────────────
function Start-GoodScenario {
    Write-Host ""
    Write-Host "================================================================" -ForegroundColor Green
    Write-Host " ZDX Demo – GOOD Score Scenario" -ForegroundColor Green
    Write-Host "================================================================" -ForegroundColor Green
    Write-Host ""
    Write-Host " This scenario simulates a healthy endpoint." -ForegroundColor Green
    Write-Host " Expected ZDX Score: 80-100 (GREEN)." -ForegroundColor Green
    Write-Host ""
    Write-Host " Tip: Run this 10 minutes before the demo to populate" -ForegroundColor Cyan
    Write-Host "      score-trend history in the ZDX portal." -ForegroundColor Cyan
    Write-Host ""
    Write-Host " Press Ctrl-C to stop." -ForegroundColor Gray
    Write-Host ""

    $iter = 0
    while ($true) {
        $iter++
        Write-Host ""
        Write-Host "$(Get-Ts) == Round $iter ==" -ForegroundColor Green

        Show-DeviceHealth

        Write-Section "Application Probes (ZDX App Score inputs)"
        foreach ($kv in $AppProbes.GetEnumerator()) {
            Invoke-ZdxProbe -AppName $kv.Key -Url $kv.Value
            Start-Sleep -Milliseconds 500
        }

        Show-PacketLoss

        if ($Iterations -gt 0 -and $iter -ge $Iterations) {
            Write-Host ""
            Write-Host "$(Get-Ts) Reached max iterations ($Iterations). Exiting." -ForegroundColor Cyan
            break
        }

        Write-Host ""
        Write-Host "$(Get-Ts) Sleeping $Interval s before next round..." -ForegroundColor Gray
        Start-Sleep -Seconds $Interval
    }
}

# ── Poor scenario ─────────────────────────────────────────────────────────────
function Start-PoorScenario {
    Write-Host ""
    Write-Host "================================================================" -ForegroundColor Red
    Write-Host " ZDX Demo – POOR Score Scenario" -ForegroundColor Red
    Write-Host "================================================================" -ForegroundColor Red
    Write-Host ""
    Write-Host " This scenario simulates a degraded endpoint." -ForegroundColor Red
    Write-Host " Expected ZDX Score: < 40 (RED)." -ForegroundColor Red
    Write-Host ""
    Write-Host " What this script does:" -ForegroundColor Yellow
    Write-Host "   1. Saturates CPU with background math jobs" -ForegroundColor Yellow
    Write-Host "   2. Allocates large memory buffers to pressure RAM" -ForegroundColor Yellow
    Write-Host "   3. Runs parallel large downloads to congest bandwidth" -ForegroundColor Yellow
    Write-Host "   4. Measures and displays degraded probe results" -ForegroundColor Yellow
    Write-Host ""
    Write-Host " Watch the ZDX portal — the score will drop within" -ForegroundColor Cyan
    Write-Host " the next probe cycle (1-5 minutes)." -ForegroundColor Cyan
    Write-Host ""
    Write-Host " Run 'demo_zdx_scores.ps1 -Scenario Restore' when done." -ForegroundColor Gray
    Write-Host ""

    # ── Step 1: CPU saturation ────────────────────────────────────────────────
    Write-Info "Starting CPU saturation ($(($env:NUMBER_OF_PROCESSORS) - 1) background jobs)..."
    $cpuJobs = @()
    $cpuCount = [int]$env:NUMBER_OF_PROCESSORS
    $loadCount = [Math]::Max(1, $cpuCount - 1)
    for ($i = 0; $i -lt $loadCount; $i++) {
        $cpuJobs += Start-Job -ScriptBlock {
            # Tight loop that keeps a core busy
            $x = 1.0
            while ($true) { $x = [Math]::Sqrt($x + 1.000001) }
        }
    }
    Write-Info "CPU load jobs started (job IDs: $($cpuJobs.Id -join ', '))"
    Write-Info "Waiting 5 s for CPU load to register..."
    Start-Sleep -Seconds 5

    # ── Step 2: Memory pressure ───────────────────────────────────────────────
    Write-Info "Allocating memory buffers to increase RAM pressure..."
    $memBuffers = @()
    for ($i = 0; $i -lt 4; $i++) {
        $memBuffers += New-Object byte[] (256MB)
    }
    Write-Info "Allocated ~1 GB of RAM"

    # ── Step 3: Bandwidth saturation ─────────────────────────────────────────
    Write-Info "Starting bandwidth saturation (parallel large downloads)..."
    $bwJobs = @()
    $testUrls = @(
        "https://speed.hetzner.de/100MB.bin"
        "https://proof.ovh.net/files/100Mb.dat"
    )
    foreach ($testUrl in $testUrls) {
        $bwJobs += Start-Job -ScriptBlock {
            param($url)
            try {
                Invoke-WebRequest -Uri $url -UseBasicParsing `
                    -OutFile ([System.IO.Path]::GetTempFileName()) `
                    -TimeoutSec 300 -ErrorAction Stop | Out-Null
            } catch { }
        } -ArgumentList $testUrl
    }
    Write-Info "Bandwidth saturation jobs started"
    Write-Info "Waiting 10 s for congestion to develop..."
    Start-Sleep -Seconds 10

    # ── Step 4: Measure and display degraded probe results ────────────────────
    Write-Host ""
    Write-Host "$(Get-Ts) Measuring degraded probe results..." -ForegroundColor Red

    Show-DeviceHealth

    Write-Section "Application Probes (expected: POOR scores)"
    foreach ($kv in $AppProbes.GetEnumerator()) {
        Invoke-ZdxProbe -AppName $kv.Key -Url $kv.Value
        Start-Sleep -Milliseconds 500
    }

    Show-PacketLoss

    Write-Host ""
    Write-Host "================================================================" -ForegroundColor Red
    Write-Host " Poor-score scenario running." -ForegroundColor Red
    Write-Host " Background load jobs are still active." -ForegroundColor Red
    Write-Host " Check the ZDX portal in 2-5 minutes to see the score drop." -ForegroundColor Red
    Write-Host " Run: .\demo_zdx_scores.ps1 -Scenario Restore  when finished." -ForegroundColor Red
    Write-Host "================================================================" -ForegroundColor Red
    Write-Host ""

    # Save job IDs so Restore can clean up
    $jobIdList = ($cpuJobs.Id + $bwJobs.Id) -join ','
    $jobIdList | Out-File -FilePath "$env:TEMP\zdx_demo_jobs.txt" -Encoding ASCII
    Write-Info "Job IDs saved to $env:TEMP\zdx_demo_jobs.txt for cleanup."
}

# ── Restore scenario ──────────────────────────────────────────────────────────
function Start-RestoreScenario {
    Write-Host ""
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host " ZDX Demo – Restore (Healthy State)" -ForegroundColor Cyan
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host ""

    # Stop all background jobs created by the Poor scenario
    $jobFile = "$env:TEMP\zdx_demo_jobs.txt"
    if (Test-Path $jobFile) {
        $savedIds = (Get-Content $jobFile) -split ',' | ForEach-Object { [int]$_ }
        foreach ($id in $savedIds) {
            $job = Get-Job -Id $id -ErrorAction SilentlyContinue
            if ($job) {
                Stop-Job  -Id $id -ErrorAction SilentlyContinue
                Remove-Job -Id $id -Force -ErrorAction SilentlyContinue
                Write-Info "Stopped job $id"
            }
        }
        Remove-Item $jobFile -Force -ErrorAction SilentlyContinue
    }

    # Also stop any remaining background jobs from this session
    Get-Job | Stop-Job  -ErrorAction SilentlyContinue
    Get-Job | Remove-Job -Force -ErrorAction SilentlyContinue
    Write-Info "All background jobs stopped."

    # Clean up temp download files
    Get-ChildItem -Path $env:TEMP -Filter "*.bin" -ErrorAction SilentlyContinue |
        Remove-Item -Force -ErrorAction SilentlyContinue
    Get-ChildItem -Path $env:TEMP -Filter "*.dat" -ErrorAction SilentlyContinue |
        Remove-Item -Force -ErrorAction SilentlyContinue
    Write-Info "Temporary download files cleaned up."

    Write-Host ""
    Write-Host " Waiting 15 s for CPU and RAM to stabilise..." -ForegroundColor Gray
    Start-Sleep -Seconds 15

    Write-Host ""
    Write-Host "$(Get-Ts) Verifying restored health:" -ForegroundColor Cyan
    Show-DeviceHealth

    Write-Section "Application Probes (expected: GOOD scores)"
    foreach ($kv in $AppProbes.GetEnumerator()) {
        Invoke-ZdxProbe -AppName $kv.Key -Url $kv.Value
        Start-Sleep -Milliseconds 500
    }

    Show-PacketLoss

    Write-Host ""
    Write-Host "================================================================" -ForegroundColor Green
    Write-Host " Endpoint restored to healthy state." -ForegroundColor Green
    Write-Host " ZDX score will recover within the next probe cycle (1-5 min)." -ForegroundColor Green
    Write-Host "================================================================" -ForegroundColor Green
    Write-Host ""
}

# ── Entry point ───────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host " ZDX Score Demo Script – Windows Client" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  Scenario : $Scenario"
Write-Host "  Interval : $Interval s  |  Iterations: $(if ($Iterations -eq 0) { 'infinite' } else { $Iterations })"
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

switch ($Scenario) {
    'Good'    { Start-GoodScenario }
    'Poor'    { Start-PoorScenario }
    'Restore' { Start-RestoreScenario }
}
