#!/usr/bin/env bash
# setup_decoy_services.sh – Deploy Zscaler Deception Lab Decoy Services (Linux)
#
# Starts lightweight honeypot services that simulate real internal servers and
# plants deception tokens (breadcrumb files) at locations an attacker would
# search first.  In a real Zscaler Deception deployment these assets are
# orchestrated by the Deception cloud; this script approximates that for the
# lab so the attacker simulation (simulate_attacker.sh) has live targets to
# interact with.
#
# Services started:
#   Port 8081  – Fake internal web portal (HTTP, Python)
#   Port 2222  – Fake SSH honeypot (TCP listener, Python)
#   Port 3307  – Fake MySQL server (TCP listener, Python)
#   Port 4445  – Fake file-service listener (TCP, Python)
#
# Breadcrumb files created:
#   /tmp/deception_demo/.aws/credentials       – Fake AWS access key
#   /tmp/deception_demo/.ssh/config            – Fake SSH config → decoy host
#   /tmp/deception_demo/app/.env               – Fake DB connection string
#   /tmp/deception_demo/backup/db_backup.sql   – Fake backup with credentials
#
# Prerequisites:
#   python3  (standard on Ubuntu 22.04)
#
# Usage:
#   sudo bash setup_decoy_services.sh           # start all decoys + tokens
#   sudo bash setup_decoy_services.sh --stop    # stop all decoy services
#   sudo bash setup_decoy_services.sh --status  # show running decoys
#
# WARNING: This script is for authorised demo environments only.
#          Do not run on production networks.

set -euo pipefail

# ── Load centralised lab config (.env) ────────────────────────────────────────
_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${_SCRIPT_DIR}/../../../scripts/lab_config.sh" 2>/dev/null \
  || source "${_SCRIPT_DIR}/../../lab_config.sh"       2>/dev/null \
  || true
LINUX_SERVER_IP="${LINUX_SERVER_IP:-192.168.1.10}"

# ── Colour helpers ─────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; MAGENTA='\033[0;35m'; WHITE='\033[1;37m'; RESET='\033[0m'

ok()      { echo -e "  ${GREEN}[OK]${RESET}     $*"; }
warn()    { echo -e "  ${YELLOW}[WARN]${RESET}   $*"; }
info()    { echo -e "  ${CYAN}[INFO]${RESET}   $*"; }
error()   { echo -e "  ${RED}[ERROR]${RESET}  $*" >&2; }
section() { echo -e "\n${CYAN}━━━ $* ━━━${RESET}"; }

# ── Paths and ports ────────────────────────────────────────────────────────────
DECOY_DIR="/tmp/deception_demo"
PID_DIR="/tmp/deception_pids"
LOG_DIR="/tmp/deception_logs"

PORT_WEB=8081
PORT_SSH=2222
PORT_DB=3307
PORT_FILE=4445

FAKE_WEB_TITLE="CorpIntranet – Internal Employee Portal"
FAKE_DB_BANNER="5.7.38-decoy-mysql"

# ── Argument parsing ───────────────────────────────────────────────────────────
ACTION="start"
while [[ $# -gt 0 ]]; do
    case "$1" in
        --stop)   ACTION="stop";   shift ;;
        --status) ACTION="status"; shift ;;
        --start)  ACTION="start";  shift ;;
        *) error "Unknown option: $1"; exit 1 ;;
    esac
done

# ── Helper: kill processes owning a port ─────────────────────────────────────
free_port() {
    local port="$1"
    local pids
    pids=$(lsof -ti tcp:"${port}" 2>/dev/null || true)
    if [[ -n "${pids}" ]]; then
        echo "${pids}" | while IFS= read -r pid; do
            [[ -n "$pid" ]] && kill "$pid" 2>/dev/null || true
        done
    fi
}

# ── Helper: start a background Python service ─────────────────────────────────
start_service() {
    local name="$1"
    local pid_file="${PID_DIR}/${name}.pid"
    local log_file="${LOG_DIR}/${name}.log"
    local python_script="$2"

    python3 - <<< "${python_script}" >> "${log_file}" 2>&1 &
    local pid=$!
    echo "${pid}" > "${pid_file}"
    ok "Started ${name} (PID ${pid})"
}

# ── Stop action ────────────────────────────────────────────────────────────────
stop_decoys() {
    section "Stopping Decoy Services"

    for pid_file in "${PID_DIR}"/*.pid; do
        [[ -f "${pid_file}" ]] || continue
        local pid
        pid=$(cat "${pid_file}")
        local name
        name=$(basename "${pid_file}" .pid)
        if kill "${pid}" 2>/dev/null; then
            ok "Stopped ${name} (PID ${pid})"
        fi
        rm -f "${pid_file}"
    done

    for port in $PORT_WEB $PORT_SSH $PORT_DB $PORT_FILE; do
        free_port "${port}"
    done

    ok "All decoy services stopped"
    ok "Breadcrumb files remain at ${DECOY_DIR} (run with --stop-all to remove)"
}

# ── Status action ──────────────────────────────────────────────────────────────
status_decoys() {
    section "Decoy Service Status"
    echo ""

    local services=("web:${PORT_WEB}" "ssh-honeypot:${PORT_SSH}" "db:${PORT_DB}" "file:${PORT_FILE}")
    for svc in "${services[@]}"; do
        local name="${svc%%:*}"
        local port="${svc##*:}"
        local pid_file="${PID_DIR}/${name}.pid"

        if [[ -f "${pid_file}" ]]; then
            local pid
            pid=$(cat "${pid_file}")
            if kill -0 "${pid}" 2>/dev/null; then
                echo -e "  ${GREEN}●${RESET} ${WHITE}${name}${RESET}  port ${port}  PID ${pid}"
            else
                echo -e "  ${RED}●${RESET} ${WHITE}${name}${RESET}  port ${port}  DEAD (stale PID file)"
            fi
        else
            echo -e "  ${YELLOW}○${RESET} ${WHITE}${name}${RESET}  port ${port}  not running"
        fi
    done
    echo ""

    section "Breadcrumb Token Status"
    echo ""
    local tokens=(
        "${DECOY_DIR}/.aws/credentials:Fake AWS credentials"
        "${DECOY_DIR}/.ssh/config:Fake SSH config"
        "${DECOY_DIR}/app/.env:Fake app .env file"
        "${DECOY_DIR}/backup/db_backup.sql:Fake database backup"
    )
    for token in "${tokens[@]}"; do
        local path="${token%%:*}"
        local label="${token##*:}"
        if [[ -f "${path}" ]]; then
            echo -e "  ${GREEN}✓${RESET} ${label}"
            echo -e "    ${CYAN}${path}${RESET}"
        else
            echo -e "  ${RED}✗${RESET} ${label} — NOT FOUND"
        fi
    done
    echo ""
}

# ── Start action ───────────────────────────────────────────────────────────────
start_decoys() {
    # Prepare directories
    mkdir -p "${PID_DIR}" "${LOG_DIR}"
    mkdir -p "${DECOY_DIR}/.aws"
    mkdir -p "${DECOY_DIR}/.ssh"
    mkdir -p "${DECOY_DIR}/app"
    mkdir -p "${DECOY_DIR}/backup"

    # Stop any leftover services first
    for port in $PORT_WEB $PORT_SSH $PORT_DB $PORT_FILE; do
        free_port "${port}"
    done

    # ── 1. Fake Internal Web Portal ──────────────────────────────────────────
    section "Starting Fake Internal Web Portal (port ${PORT_WEB})"

    # Build the fake login page HTML
    cat > "${DECOY_DIR}/fake_portal.html" << 'HTML'
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>CorpIntranet – Internal Employee Portal</title>
<style>
  body{font-family:Arial,sans-serif;background:#1a3c5e;display:flex;
       justify-content:center;align-items:center;height:100vh;margin:0;}
  .box{background:#fff;padding:40px;border-radius:8px;width:360px;
       box-shadow:0 4px 20px rgba(0,0,0,0.3);}
  h2{text-align:center;color:#1a3c5e;margin-bottom:6px;}
  p{text-align:center;color:#666;font-size:13px;margin-bottom:24px;}
  input{width:100%;padding:10px;margin:8px 0;border:1px solid #ccc;
        border-radius:4px;box-sizing:border-box;font-size:14px;}
  button{width:100%;padding:12px;background:#1a3c5e;color:#fff;border:none;
         border-radius:4px;font-size:15px;cursor:pointer;margin-top:8px;}
  button:hover{background:#2a5080;}
  .logo{text-align:center;font-size:28px;margin-bottom:8px;}
</style>
</head>
<body>
<div class="box">
  <div class="logo">🏢</div>
  <h2>CorpIntranet</h2>
  <p>Internal Employee Portal — Authorised Access Only</p>
  <form method="POST" action="/login">
    <input type="text"     name="username" placeholder="Corporate Username" autocomplete="off">
    <input type="password" name="password" placeholder="Password">
    <button type="submit">Sign In</button>
  </form>
</div>
</body>
</html>
HTML

    cat > "${DECOY_DIR}/fake_portal_logged.html" << 'HTML'
<!DOCTYPE html>
<html lang="en">
<head><meta charset="UTF-8"><title>CorpIntranet – Dashboard</title>
<style>body{font-family:Arial,sans-serif;background:#f4f6f8;padding:40px;}
h1{color:#1a3c5e;}</style></head>
<body>
<h1>Welcome to CorpIntranet</h1>
<p>Loading your personalised dashboard…</p>
</body>
</html>
HTML

    # Python HTTP server that logs all requests with full detail
    start_service "web" "
import http.server, socketserver, urllib.parse, datetime, sys, os

PORT = ${PORT_WEB}
LOG  = '${LOG_DIR}/web_access.log'

class DecoyHandler(http.server.BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):
        ts  = datetime.datetime.now().isoformat()
        msg = fmt % args
        line = f'[{ts}] {self.client_address[0]} {msg}'
        print(line, flush=True)
        with open(LOG, 'a') as f:
            f.write(line + '\n')

    def send_page(self, code, path):
        try:
            with open(path, 'rb') as f:
                content = f.read()
            self.send_response(code)
            self.send_header('Content-Type', 'text/html')
            self.send_header('Server', 'Apache/2.4.41 (Ubuntu)')
            self.end_headers()
            self.wfile.write(content)
        except Exception as e:
            self.send_error(500)

    def do_GET(self):
        self.send_page(200, '${DECOY_DIR}/fake_portal.html')

    def do_POST(self):
        length = int(self.headers.get('Content-Length', 0))
        body   = self.rfile.read(length).decode('utf-8', errors='replace')
        ts     = datetime.datetime.now().isoformat()
        creds  = urllib.parse.unquote_plus(body)
        alert  = f'[{ts}] DECEPTION_ALERT CREDENTIAL_SUBMISSION src={self.client_address[0]} path={self.path} body={creds}'
        print(alert, flush=True)
        with open(LOG, 'a') as f:
            f.write(alert + '\n')
        self.send_page(200, '${DECOY_DIR}/fake_portal_logged.html')

with socketserver.TCPServer(('0.0.0.0', PORT), DecoyHandler) as httpd:
    httpd.serve_forever()
"

    # ── 2. Fake SSH Honeypot ─────────────────────────────────────────────────
    section "Starting Fake SSH Honeypot (port ${PORT_SSH})"

    start_service "ssh-honeypot" "
import socket, threading, datetime, time

PORT = ${PORT_SSH}
LOG  = '${LOG_DIR}/ssh_access.log'
BANNER = b'SSH-2.0-OpenSSH_8.2p1 Ubuntu-4ubuntu0.5\r\n'

def handle(conn, addr):
    ts = datetime.datetime.now().isoformat()
    try:
        conn.settimeout(30)
        conn.sendall(BANNER)
        data = b''
        try:
            data = conn.recv(1024)
        except Exception:
            pass
        decoded = data.decode('utf-8', errors='replace').strip()
        alert = f'[{ts}] DECEPTION_ALERT SSH_PROBE src={addr[0]}:{addr[1]} banner_response={repr(decoded)}'
        print(alert, flush=True)
        with open(LOG, 'a') as f:
            f.write(alert + '\n')
        # Simulate slow auth failure to hold attacker attention
        time.sleep(3)
        conn.sendall(b'Permission denied (publickey,password).\r\n')
    except Exception as e:
        pass
    finally:
        try:
            conn.close()
        except Exception:
            pass

sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
sock.bind(('0.0.0.0', PORT))
sock.listen(10)
print(f'SSH honeypot listening on port {PORT}', flush=True)
while True:
    try:
        conn, addr = sock.accept()
        t = threading.Thread(target=handle, args=(conn, addr), daemon=True)
        t.start()
    except Exception:
        pass
"

    # ── 3. Fake MySQL Server ─────────────────────────────────────────────────
    section "Starting Fake Database Server (port ${PORT_DB})"

    start_service "db" "
import socket, threading, datetime, struct

PORT   = ${PORT_DB}
LOG    = '${LOG_DIR}/db_access.log'

# Minimal MySQL greeting packet (version string)
def mysql_greeting():
    version    = b'${FAKE_DB_BANNER}\x00'
    thread_id  = struct.pack('<I', 1)
    salt       = b'deceptsalt12\x00'
    caps       = struct.pack('<H', 0xF7FF)
    charset    = b'\x08'
    status     = struct.pack('<H', 2)
    pad        = b'\x00' * 13
    salt2      = b'deceptsalt3456789\x00'
    auth       = b'mysql_native_password\x00'
    payload    = version + thread_id + salt + caps + charset + status + pad + salt2 + auth
    length     = struct.pack('<I', len(payload))[:3]
    seq        = b'\x00'
    return length + seq + payload

def handle(conn, addr):
    ts = datetime.datetime.now().isoformat()
    try:
        conn.settimeout(20)
        conn.sendall(mysql_greeting())
        data = b''
        try:
            data = conn.recv(512)
        except Exception:
            pass
        decoded = data[4:].decode('utf-8', errors='replace').strip('\x00')
        alert = f'[{ts}] DECEPTION_ALERT DB_PROBE src={addr[0]}:{addr[1]} auth_packet={repr(decoded[:80])}'
        print(alert, flush=True)
        with open(LOG, 'a') as f:
            f.write(alert + '\n')
        err = b'\xff\x15\x04#28000Access denied for user'
        pkt = struct.pack('<I', len(err))[:3] + b'\x02' + err
        conn.sendall(pkt)
    except Exception:
        pass
    finally:
        try:
            conn.close()
        except Exception:
            pass

sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
sock.bind(('0.0.0.0', PORT))
sock.listen(10)
print(f'Fake MySQL listening on port {PORT}', flush=True)
while True:
    try:
        conn, addr = sock.accept()
        t = threading.Thread(target=handle, args=(conn, addr), daemon=True)
        t.start()
    except Exception:
        pass
"

    # ── 4. Fake File Service ──────────────────────────────────────────────────
    section "Starting Fake File Service (port ${PORT_FILE})"

    start_service "file" "
import socket, threading, datetime

PORT = ${PORT_FILE}
LOG  = '${LOG_DIR}/file_access.log'
BANNER = b'220 CorpFileServer FTP-like service ready\r\n'

def handle(conn, addr):
    ts = datetime.datetime.now().isoformat()
    try:
        conn.settimeout(20)
        conn.sendall(BANNER)
        data = b''
        try:
            data = conn.recv(512)
        except Exception:
            pass
        decoded = data.decode('utf-8', errors='replace').strip()
        alert = f'[{ts}] DECEPTION_ALERT FILE_SERVICE_PROBE src={addr[0]}:{addr[1]} banner_response={repr(decoded)}'
        print(alert, flush=True)
        with open(LOG, 'a') as f:
            f.write(alert + '\n')
        conn.sendall(b'530 Authentication failed.\r\n')
    except Exception:
        pass
    finally:
        try:
            conn.close()
        except Exception:
            pass

sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
sock.bind(('0.0.0.0', PORT))
sock.listen(10)
print(f'Fake file service listening on port {PORT}', flush=True)
while True:
    try:
        conn, addr = sock.accept()
        t = threading.Thread(target=handle, args=(conn, addr), daemon=True)
        t.start()
    except Exception:
        pass
"

    # ── 5. Plant Deception Token / Breadcrumb Files ───────────────────────────
    section "Planting Deception Tokens (Breadcrumb Files)"

    # Fake AWS credentials
    # NOTE: The key IDs below are intentional deception tokens (lures) for
    # the demo lab.  They are not real AWS credentials.
    cat > "${DECOY_DIR}/.aws/credentials" << 'AWSCREDS'
[default]
# Last updated by infra-automation on 2024-11-03
# DECEPTION TOKEN - DO NOT USE - lab lure only
aws_access_key_id     = DEMO-FAKE-KEY-ID-LAB1-REPLACE
aws_secret_access_key = DEMO-FAKE-SECRET-LAB1-NOT-A-REAL-AWS-KEY-REPLACE
region                = us-east-1

[prod-backup]
aws_access_key_id     = DEMO-FAKE-KEY-ID-LAB2-REPLACE
aws_secret_access_key = DEMO-FAKE-SECRET-LAB2-NOT-A-REAL-AWS-KEY-REPLACE
region                = us-west-2
AWSCREDS
    ok "Planted fake AWS credentials: ${DECOY_DIR}/.aws/credentials"

    # Fake SSH config pointing to the decoy SSH honeypot
    local_ip=$(hostname -I 2>/dev/null | awk '{print $1}')
    cat > "${DECOY_DIR}/.ssh/config" << SSHCONF
# Corporate SSH shortcuts – generated by IT provisioning script
# Last sync: 2024-10-22

Host mgmt-jump
    HostName ${local_ip}
    Port 2222
    User lab-admin
    IdentityFile ~/.ssh/id_rsa_corp
    ServerAliveInterval 60

Host prod-db-01
    HostName ${LINUX_SERVER_IP}
    Port 22
    User dbadmin
    IdentityFile ~/.ssh/id_rsa_corp

Host backup-store
    HostName ${LINUX_SERVER_IP}
    Port 2222
    User backup-svc
    IdentityFile ~/.ssh/id_rsa_backup
SSHCONF
    ok "Planted fake SSH config: ${DECOY_DIR}/.ssh/config"

    # Fake application .env file
    cat > "${DECOY_DIR}/app/.env" << 'ENVFILE'
# Application configuration – DO NOT COMMIT
# Generated by deploy.sh on 2024-09-14

APP_ENV=production
APP_DEBUG=false
APP_KEY=base64:FAKEDKEY12345ABCDE=

DB_CONNECTION=mysql
DB_HOST=192.168.1.10
DB_PORT=3307
DB_DATABASE=corpdb_prod
DB_USERNAME=app_prod_user
DB_PASSWORD=Pr0dDB$ecret!2024

REDIS_HOST=192.168.1.10
REDIS_PASSWORD=null
REDIS_PORT=6379

AWS_ACCESS_KEY_ID=DEMO-FAKE-KEY-ID-ENV-REPLACE
AWS_SECRET_ACCESS_KEY=DEMO-FAKE-SECRET-ENV-NOT-A-REAL-AWS-KEY-REPLACE
AWS_DEFAULT_REGION=us-east-1
AWS_BUCKET=corp-prod-backups-us-east

MAIL_MAILER=smtp
MAIL_HOST=smtp.corp.internal
MAIL_USERNAME=mailer@corp.internal
MAIL_PASSWORD=Smtp@Pass2024!
ENVFILE
    sed -i "s/192\.168\.1\.10/${LINUX_SERVER_IP}/g" "${DECOY_DIR}/app/.env"
    ok "Planted fake .env config: ${DECOY_DIR}/app/.env"

    # Fake database backup with credentials in header
    cat > "${DECOY_DIR}/backup/db_backup.sql" << 'SQLFILE'
-- CorpDB Production Backup
-- Created: 2024-11-01 02:00:01 UTC
-- Source:  prod-db-01.corp.internal (192.168.1.10:3307)
-- User:    backup_svc@192.168.1.% (password: BackupSvc!DB2024)
-- Schema:  corpdb_prod
--
-- Restore cmd:
--   mysql -h 192.168.1.10 -P 3307 -u backup_svc -p'BackupSvc!DB2024' corpdb_prod < db_backup.sql

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
SET time_zone = "+00:00";

CREATE DATABASE IF NOT EXISTS `corpdb_prod` DEFAULT CHARACTER SET utf8mb4;
USE `corpdb_prod`;

-- Sample table structure (truncated for brevity)
CREATE TABLE `users` (
  `id`         int(11) NOT NULL AUTO_INCREMENT,
  `username`   varchar(64) NOT NULL,
  `email`      varchar(128) NOT NULL,
  `password`   varchar(255) NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
SQLFILE
    sed -i "s/192\.168\.1\.10/${LINUX_SERVER_IP}/g" "${DECOY_DIR}/backup/db_backup.sql"
    sed -i "s/192\.168\.1\.%/${LAB_SUBNET}.%/g"     "${DECOY_DIR}/backup/db_backup.sql"
    ok "Planted fake DB backup: ${DECOY_DIR}/backup/db_backup.sql"

    # ── Summary ──────────────────────────────────────────────────────────────
    echo ""
    echo -e "${GREEN}$(printf '═%.0s' {1..60})${RESET}"
    echo -e "${GREEN}  Decoy Services Active – Demo Ready${RESET}"
    echo -e "${GREEN}$(printf '═%.0s' {1..60})${RESET}"
    echo ""
    echo -e "  ${WHITE}Decoy Services:${RESET}"
    echo -e "    ${CYAN}Fake Internal Web Portal  :${RESET} http://$(hostname -I | awk '{print $1}'):${PORT_WEB}"
    echo -e "    ${CYAN}Fake SSH Honeypot         :${RESET} $(hostname -I | awk '{print $1}'):${PORT_SSH}"
    echo -e "    ${CYAN}Fake MySQL Server         :${RESET} $(hostname -I | awk '{print $1}'):${PORT_DB}"
    echo -e "    ${CYAN}Fake File Service         :${RESET} $(hostname -I | awk '{print $1}'):${PORT_FILE}"
    echo ""
    echo -e "  ${WHITE}Deception Tokens:${RESET}"
    echo -e "    ${CYAN}AWS credentials :${RESET} ${DECOY_DIR}/.aws/credentials"
    echo -e "    ${CYAN}SSH config      :${RESET} ${DECOY_DIR}/.ssh/config"
    echo -e "    ${CYAN}App .env        :${RESET} ${DECOY_DIR}/app/.env"
    echo -e "    ${CYAN}DB backup       :${RESET} ${DECOY_DIR}/backup/db_backup.sql"
    echo ""
    echo -e "  ${WHITE}Service logs:${RESET}     ${LOG_DIR}/"
    echo ""
    echo -e "  ${YELLOW}DEMO TIP:${RESET} Run simulate_attacker.sh to trigger alerts on these decoys."
    echo -e "  ${YELLOW}         ${RESET} Watch the logs in ${LOG_DIR}/ for DECEPTION_ALERT lines."
    echo ""
}

# ── Dispatch ───────────────────────────────────────────────────────────────────
echo ""
echo -e "${MAGENTA}$(printf '═%.0s' {1..60})${RESET}"
echo -e "${MAGENTA}  Zscaler Deception – Decoy Service Setup${RESET}"
echo -e "${MAGENTA}$(printf '═%.0s' {1..60})${RESET}"
echo ""

case "${ACTION}" in
    start)  start_decoys  ;;
    stop)   stop_decoys   ;;
    status) status_decoys ;;
esac
