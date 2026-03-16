#!/usr/bin/env bash
# =============================================================================
# demo_discovered_apps.sh
# Starts (or stops) lightweight services on the Ubuntu Server that will be
# picked up by ZPA App Discovery, simulating "shadow IT" apps that IT doesn't
# know about yet.
#
# Usage:
#   sudo bash demo_discovered_apps.sh           # start all services
#   sudo bash demo_discovered_apps.sh --stop    # stop all services
#
# Services started:
#   Port 5000  – Python Flask "Employee Portal" (HTTP)
#   Port 6379  – Fake Redis listener (TCP echo)
#   Port 8888  – Python "Jupyter-style" notebook stub (HTTP)
#   Port 9200  – Fake Elasticsearch stub (HTTP)
# =============================================================================

set -euo pipefail

# ── Colour helpers ────────────────────────────────────────────────────────────
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

PIDFILE_DIR="/var/run/zpa-demo"
STOP_MODE=false

# ── Argument parsing ─────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --stop) STOP_MODE=true; shift ;;
    *) error "Unknown argument: $1"; exit 1 ;;
  esac
done

# ── Dependency checks ─────────────────────────────────────────────────────────
ensure_python3() {
  if ! command -v python3 &>/dev/null; then
    info "Installing python3..."
    apt-get install -y -qq python3
  fi
}

ensure_nc() {
  if ! command -v nc &>/dev/null; then
    info "Installing netcat-openbsd..."
    apt-get install -y -qq netcat-openbsd
  fi
}

# ── Stop all demo services ────────────────────────────────────────────────────
stop_services() {
  info "Stopping all ZPA App Discovery demo services..."
  local stopped=0
  for pidfile in "${PIDFILE_DIR}"/*.pid; do
    [[ -f "${pidfile}" ]] || continue
    pid=$(cat "${pidfile}")
    name=$(basename "${pidfile}" .pid)
    if kill "${pid}" 2>/dev/null; then
      info "Stopped ${name} (PID ${pid})"
      (( stopped++ )) || true
    else
      warn "${name} (PID ${pid}) was not running."
    fi
    rm -f "${pidfile}"
  done
  [[ "${stopped}" -gt 0 ]] && info "All services stopped." \
    || info "No running services found."
}

# ── Start helpers ─────────────────────────────────────────────────────────────
mkdir -p "${PIDFILE_DIR}"

start_python_http() {
  local port="$1"
  local title="$2"
  local pidfile="${PIDFILE_DIR}/demo-port${port}.pid"

  if [[ -f "${pidfile}" ]] && kill -0 "$(cat "${pidfile}")" 2>/dev/null; then
    warn "Service on port ${port} already running (PID $(cat "${pidfile}"))."
    return
  fi

  python3 - <<PYEOF &
import http.server, socketserver, os

class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        body = b"""<!DOCTYPE html>
<html><head><title>${title}</title></head>
<body>
  <h1>${title}</h1>
  <p>This is a simulated internal application running on port ${port}.</p>
  <p>It was discovered automatically by ZPA App Discovery.</p>
</body></html>"""
        self.send_response(200)
        self.send_header("Content-Type", "text/html")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, fmt, *args):
        pass  # suppress default log noise

with socketserver.TCPServer(("0.0.0.0", ${port}), Handler) as httpd:
    httpd.serve_forever()
PYEOF

  echo $! > "${pidfile}"
  sleep 0.5
  if kill -0 "$(cat "${pidfile}")" 2>/dev/null; then
    info "Started ${title} on port ${port} (PID $(cat "${pidfile}"))"
  else
    error "Failed to start service on port ${port}"
  fi
}

start_tcp_echo() {
  local port="$1"
  local name="$2"
  local pidfile="${PIDFILE_DIR}/demo-port${port}.pid"

  if [[ -f "${pidfile}" ]] && kill -0 "$(cat "${pidfile}")" 2>/dev/null; then
    warn "Service on port ${port} already running."
    return
  fi

  # Simple TCP listener that accepts connections and echoes "+PONG\r\n"
  # (mimics a minimal Redis-like handshake for App Discovery purposes)
  # A short sleep prevents a tight loop if nc fails repeatedly.
  while true; do
    echo -e "+PONG\r" | nc -l -p "${port}" -q 1 2>/dev/null || sleep 1
  done &

  echo $! > "${pidfile}"
  sleep 0.5
  info "Started ${name} TCP listener on port ${port} (PID $(cat "${pidfile}"))"
}

# ── Main ──────────────────────────────────────────────────────────────────────
if "${STOP_MODE}"; then
  stop_services
  exit 0
fi

info "============================================================"
info " ZPA App Discovery Demo – Starting Shadow-IT Services"
info "============================================================"
info " These services simulate undocumented applications that ZPA"
info " App Discovery will find and surface in the Admin Portal."
info ""

ensure_python3
ensure_nc

# HTTP services (simulate web apps on non-standard ports)
start_python_http 5000 "Employee Self-Service Portal"
start_python_http 8888 "Internal Analytics Dashboard"
start_python_http 9200 "Search & Indexing Service"

# TCP service (simulate a database/cache on non-standard port)
start_tcp_echo 6379 "In-Memory Cache (Redis-style)"

info ""
info "All demo services are running."
info ""
info "Now wait 2–3 minutes, then check the ZPA Admin Portal:"
info "  Applications → App Discovery"
info ""
info "You should see ports 5000, 6379, 8888, and 9200 appear as"
info "discovered applications."
info ""
info "To stop all services, run:"
info "  sudo bash demo_discovered_apps.sh --stop"
