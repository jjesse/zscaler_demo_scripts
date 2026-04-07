#Requires -Version 5.1
<#
.SYNOPSIS
    Deploy Zscaler Deception tokens (lures / breadcrumbs) on a Windows endpoint.

.DESCRIPTION
    Plants realistic-looking fake credentials, configuration files, and saved
    passwords in the locations an attacker would search first after compromising
    a Windows machine.  In a production Zscaler Deception deployment these tokens
    are pushed by the Deception Orchestrator; this script replicates that for
    the lab environment.

    Tokens deployed:
      - Fake AWS credentials file   ($HOME\.aws\credentials)
      - Fake SSH private key config ($HOME\.ssh\config)
      - Fake application .env file  ($HOME\Documents\Projects\webapp\.env)
      - Fake database backup        ($HOME\Documents\Backups\db_backup.sql)
      - Fake passwords CSV          ($HOME\Downloads\passwords_export.csv)
      - Fake KeePass path hint file ($HOME\Documents\vault_location.txt)
      - Windows Credential Manager  (fake SMB share entry via cmdkey)

    ⚠ WARNING: For authorised demo lab environments only.
               Remove tokens after the demo with -Remove switch.

.PARAMETER Remove
    Remove all deployed deception tokens and clear the Credential Manager entry.

.PARAMETER Status
    Show which tokens are currently deployed on this machine.

.EXAMPLE
    .\scripts\deception\windows\deploy_deception_tokens.ps1

.EXAMPLE
    .\scripts\deception\windows\deploy_deception_tokens.ps1 -Remove

.EXAMPLE
    .\scripts\deception\windows\deploy_deception_tokens.ps1 -Status
#>

[CmdletBinding(DefaultParameterSetName = 'Deploy')]
param(
    [Parameter(ParameterSetName = 'Remove')]
    [switch]$Remove,

    [Parameter(ParameterSetName = 'Status')]
    [switch]$Status
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'SilentlyContinue'

# ---------------------------------------------------------------------------
# Output helpers
# ---------------------------------------------------------------------------
function Write-Ok      { param($Msg) Write-Host "  [OK]      $Msg" -ForegroundColor Green }
function Write-Planted { param($Msg) Write-Host "  [PLANTED] $Msg" -ForegroundColor Yellow }
function Write-Removed { param($Msg) Write-Host "  [REMOVED] $Msg" -ForegroundColor Cyan }
function Write-Info    { param($Msg) Write-Host "  [INFO]    $Msg" -ForegroundColor Cyan }
function Write-Warn    { param($Msg) Write-Host "  [WARN]    $Msg" -ForegroundColor Yellow }
function Write-Section { param($Msg) Write-Host "`n  ━━━ $Msg ━━━`n" -ForegroundColor Magenta }
function Write-Alert   { param($Msg) Write-Host "  [DECEPTION ALERT EXPECTED] $Msg" -ForegroundColor Red }

# ---------------------------------------------------------------------------
# Token definitions
# ---------------------------------------------------------------------------
$TokenBase = Join-Path $env:USERPROFILE '.deception_tokens'

$Tokens = @{
    AwsCredentials  = Join-Path $env:USERPROFILE '.aws\credentials'
    SshConfig       = Join-Path $env:USERPROFILE '.ssh\config'
    EnvFile         = Join-Path $env:USERPROFILE 'Documents\Projects\webapp\.env'
    DbBackup        = Join-Path $env:USERPROFILE 'Documents\Backups\db_backup.sql'
    PasswordsCsv    = Join-Path $env:USERPROFILE 'Downloads\passwords_export.csv'
    KeePassHint     = Join-Path $env:USERPROFILE 'Documents\vault_location.txt'
}

$FakeSmb        = '\\192.168.1.10\CorpShare'
$FakeSmbUser    = 'CORP\svc-backup'
$FakeSmbPass    = 'BackupSvc!2024fake'
$CredMgrTarget  = 'LegacyGeneric:target=\\192.168.1.10\CorpShare'

# ---------------------------------------------------------------------------
# Status
# ---------------------------------------------------------------------------
function Show-TokenStatus {
    Write-Section "Deception Token Status"

    foreach ($key in $Tokens.Keys) {
        $path = $Tokens[$key]
        if (Test-Path $path) {
            Write-Host "  ✓  $key" -ForegroundColor Green
            Write-Host "     $path" -ForegroundColor DarkGray
        } else {
            Write-Host "  ✗  $key  —  not deployed" -ForegroundColor Red
            Write-Host "     $path" -ForegroundColor DarkGray
        }
    }

    Write-Host ""
    $credEntry = cmdkey /list 2>$null | Select-String 'CorpShare'
    if ($credEntry) {
        Write-Host "  ✓  Windows Credential Manager — SMB decoy entry present" -ForegroundColor Green
    } else {
        Write-Host "  ✗  Windows Credential Manager — SMB decoy entry NOT present" -ForegroundColor Red
    }
    Write-Host ""
}

# ---------------------------------------------------------------------------
# Remove
# ---------------------------------------------------------------------------
function Remove-AllTokens {
    Write-Section "Removing Deception Tokens"

    foreach ($key in $Tokens.Keys) {
        $path = $Tokens[$key]
        if (Test-Path $path) {
            Remove-Item $path -Force -ErrorAction SilentlyContinue
            Write-Removed "$key  →  $path"
        }
    }

    # Remove Credential Manager entry
    $null = cmdkey /delete:$FakeSmb 2>$null
    Write-Removed "Windows Credential Manager entry for $FakeSmb"

    # Remove empty parent directories we created
    $dirsToRemove = @(
        (Split-Path $Tokens.AwsCredentials),
        (Split-Path $Tokens.EnvFile),
        (Split-Path $Tokens.DbBackup)
    )
    foreach ($dir in $dirsToRemove) {
        if (Test-Path $dir) {
            $contents = Get-ChildItem $dir -ErrorAction SilentlyContinue
            if (-not $contents) {
                Remove-Item $dir -Force -ErrorAction SilentlyContinue
            }
        }
    }

    Write-Ok "All deception tokens removed."
    Write-Host ""
}

# ---------------------------------------------------------------------------
# Deploy
# ---------------------------------------------------------------------------
function Deploy-AllTokens {
    Write-Section "Deploying Deception Tokens"

    # ── Token 1: Fake AWS Credentials ───────────────────────────────────────
    Write-Info "Planting fake AWS credentials…"
    $awsDir = Split-Path $Tokens.AwsCredentials
    New-Item -ItemType Directory -Path $awsDir -Force | Out-Null

    Set-Content -Path $Tokens.AwsCredentials -Encoding UTF8 -Value @'
[default]
# IT automation account — last rotated 2024-10-15
# DECEPTION TOKEN - DO NOT USE - lab lure only
aws_access_key_id     = DEMO-FAKE-KEY-ID-WIN-LAB1-REPLACE
aws_secret_access_key = DEMO-FAKE-SECRET-WIN-LAB1-NOT-A-REAL-AWS-KEY-REPLACE
region                = us-east-1
output                = json

[prod-deploy]
aws_access_key_id     = DEMO-FAKE-KEY-ID-WIN-LAB2-REPLACE
aws_secret_access_key = DEMO-FAKE-SECRET-WIN-LAB2-NOT-A-REAL-AWS-KEY-REPLACE
region                = us-west-2
'@
    Write-Planted "AWS credentials  →  $($Tokens.AwsCredentials)"

    # ── Token 2: Fake SSH Config ─────────────────────────────────────────────
    Write-Info "Planting fake SSH client config…"
    $sshDir = Split-Path $Tokens.SshConfig
    New-Item -ItemType Directory -Path $sshDir -Force | Out-Null

    Set-Content -Path $Tokens.SshConfig -Encoding UTF8 -Value @'
# Corporate SSH shortcuts — generated by IT provisioning 2024-09-22
# DO NOT EDIT — managed by deploy.sh

Host mgmt-jump
    HostName 192.168.1.10
    Port 2222
    User lab-admin
    IdentityFile ~/.ssh/id_rsa_corp
    ServerAliveInterval 60

Host prod-db
    HostName 192.168.1.10
    Port 22
    User dbadmin
    IdentityFile ~/.ssh/id_rsa_corp

Host backup-sftp
    HostName 192.168.1.10
    Port 2222
    User backup-svc
    IdentityFile ~/.ssh/id_rsa_backup
'@
    Write-Planted "SSH config  →  $($Tokens.SshConfig)"

    # ── Token 3: Fake Application .env ──────────────────────────────────────
    Write-Info "Planting fake application .env file…"
    $envDir = Split-Path $Tokens.EnvFile
    New-Item -ItemType Directory -Path $envDir -Force | Out-Null

    Set-Content -Path $Tokens.EnvFile -Encoding UTF8 -Value @'
# Application configuration — DO NOT COMMIT TO SOURCE CONTROL
# Last updated by CI/CD pipeline 2024-11-02

APP_ENV=production
APP_DEBUG=false
APP_KEY=base64:FAKEDKEY12345ABCDE+XYZ=

DB_CONNECTION=mysql
DB_HOST=192.168.1.10
DB_PORT=3307
DB_DATABASE=corpdb_prod
DB_USERNAME=app_prod_user
DB_PASSWORD=Pr0dDB$ecret!2024

REDIS_HOST=192.168.1.10
REDIS_PASSWORD=null
REDIS_PORT=6379

AWS_ACCESS_KEY_ID=DEMO-FAKE-KEY-ID-WIN-ENV-REPLACE
AWS_SECRET_ACCESS_KEY=DEMO-FAKE-SECRET-WIN-ENV-NOT-A-REAL-AWS-KEY-REPLACE
AWS_DEFAULT_REGION=us-east-1
AWS_BUCKET=corp-prod-backups

MAIL_HOST=smtp.corp.internal
MAIL_USERNAME=mailer@corp.internal
MAIL_PASSWORD=Smtp@Pass2024!
'@
    Write-Planted "App .env  →  $($Tokens.EnvFile)"

    # ── Token 4: Fake Database Backup ────────────────────────────────────────
    Write-Info "Planting fake database backup…"
    $backupDir = Split-Path $Tokens.DbBackup
    New-Item -ItemType Directory -Path $backupDir -Force | Out-Null

    Set-Content -Path $Tokens.DbBackup -Encoding UTF8 -Value @'
-- CorpDB Production Backup
-- Created: 2024-11-01 02:00:01 UTC
-- Source:  prod-db-01.corp.internal (192.168.1.10:3307)
-- User:    backup_svc@192.168.1.% (password: BackupSvc!DB2024)
-- Schema:  corpdb_prod
--
-- Restore:
--   mysql -h 192.168.1.10 -P 3307 -u backup_svc -p'BackupSvc!DB2024' corpdb_prod < db_backup.sql

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
SET time_zone = "+00:00";
CREATE DATABASE IF NOT EXISTS `corpdb_prod` DEFAULT CHARACTER SET utf8mb4;
USE `corpdb_prod`;
'@
    Write-Planted "DB backup  →  $($Tokens.DbBackup)"

    # ── Token 5: Fake Passwords CSV ──────────────────────────────────────────
    Write-Info "Planting fake password export CSV…"
    Set-Content -Path $Tokens.PasswordsCsv -Encoding UTF8 -Value @"
name,url,username,password,notes
CorpIntranet,http://192.168.1.10:8081,admin,Welcome1!fake,Employee intranet
Corp VPN,https://vpn.corp.internal,jsmith,Vpn@Pass2024!,Legacy VPN (pre-ZPA)
Legacy FileServer,\\192.168.1.10\CorpShare,CORP\svc-backup,BackupSvc!2024fake,Backup service account
Dev MySQL,192.168.1.10:3307,devuser,DevDB#2024!,Dev database
Corp WiFi,N/A,corpwifi,CorpWifi@2024,Office SSID
"@
    Write-Planted "Passwords CSV  →  $($Tokens.PasswordsCsv)"

    # ── Token 6: KeePass Hint File ───────────────────────────────────────────
    Write-Info "Planting KeePass vault location hint…"
    Set-Content -Path $Tokens.KeePassHint -Encoding UTF8 -Value @"
Corporate Password Vault
========================
File location : \\192.168.1.20\SharedDocs\IT\corp_vault.kdbx
Master password hint: standard IT prefix + year
Backup copy   : C:\Users\admin\Documents\corp_vault_backup.kdbx

Emergency access: contact helpdesk@corp.internal
"@
    Write-Planted "KeePass hint  →  $($Tokens.KeePassHint)"

    # ── Token 7: Windows Credential Manager ─────────────────────────────────
    Write-Info "Adding fake SMB credential to Windows Credential Manager…"
    $null = cmdkey /add:$FakeSmb /user:$FakeSmbUser /pass:$FakeSmbPass 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Planted "Windows Credential Manager  →  $FakeSmb ($FakeSmbUser)"
    } else {
        Write-Warn "cmdkey failed — Credential Manager token not added (non-critical)"
    }

    # ── Summary ──────────────────────────────────────────────────────────────
    Write-Host ""
    Write-Host "  ══════════════════════════════════════════════════════" -ForegroundColor Green
    Write-Host "   Deception Tokens Deployed — Endpoint Ready" -ForegroundColor Green
    Write-Host "  ══════════════════════════════════════════════════════" -ForegroundColor Green
    Write-Host ""
    Write-Info "Tokens will trigger Deception alerts when an attacker:"
    Write-Host "  • Reads the fake AWS credentials file   → Cloud Canary Token alert" -ForegroundColor Cyan
    Write-Host "  • Uses the fake SSH config to connect   → Decoy SSH Honeypot alert" -ForegroundColor Cyan
    Write-Host "  • Uses the web portal password          → Decoy Web Portal alert"   -ForegroundColor Cyan
    Write-Host "  • Reads the DB backup file              → Credential Lure alert"    -ForegroundColor Cyan
    Write-Host "  • Opens the passwords CSV               → File Token access alert"  -ForegroundColor Cyan
    Write-Host "  • Connects to the Credential Mgr SMB   → SMB Decoy alert"          -ForegroundColor Cyan
    Write-Host ""
    Write-Info "Run simulate_attacker.ps1 to trigger the alerts live."
    Write-Info "Run this script with -Remove to clean up after the demo."
    Write-Host ""
}

# ---------------------------------------------------------------------------
# Dispatch
# ---------------------------------------------------------------------------
Clear-Host
Write-Host ""
Write-Host "  ╔══════════════════════════════════════════════════════╗" -ForegroundColor Magenta
Write-Host "  ║   Zscaler Deception — Token Deployment (Windows)    ║" -ForegroundColor Magenta
Write-Host "  ╚══════════════════════════════════════════════════════╝" -ForegroundColor Magenta
Write-Host ""

if ($Status) {
    Show-TokenStatus
} elseif ($Remove) {
    Remove-AllTokens
} else {
    Deploy-AllTokens
}
