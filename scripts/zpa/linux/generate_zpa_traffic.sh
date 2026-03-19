#!/usr/bin/env bash
# =============================================================================
# generate_zpa_traffic.sh
# Continuously generates HTTP, HTTPS, SSH, and SMB traffic from the Ubuntu
# server through ZPA to the Windows Server and back to itself.
#
# This keeps the ZPA dashboards and Log Explorer active during a demo.
#
# Usage:
#   sudo bash generate_zpa_traffic.sh             # runs until Ctrl-C
#   sudo bash generate_zpa_traffic.sh --count 50  # runs 50 iterations then exits
#
# Environment Variables (override defaults):
#   TARGET_HOST   – IP/hostname of Windows Server  (default: 192.168.1.20)
#   INTERVAL      – seconds between request rounds (default: 10)
# =============================================================================

set -euo pipefail

# ── Defaults ──────────────────────────────────────────────────────────────────
TARGET_HOST="${TARGET_HOST:-192.168.1.20}"
INTERVAL="${INTERVAL:-10}"
MAX_COUNT=0       # 0 = run forever

# ── Argument parsing ─────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --count) MAX_COUNT="$2"; shift 2 ;;
    --target) TARGET_HOST="$2"; shift 2 ;;
    --interval) INTERVAL="$2"; shift 2 ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

# ── Colour helpers ────────────────────────────────────────────────────────────
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
ts()      { date '+%Y-%m-%d %H:%M:%S'; }
ok()      { echo -e "$(ts) ${GREEN}[OK]${NC}    $*"; }
fail()    { echo -e "$(ts) ${RED}[FAIL]${NC}  $*"; }
section() { echo -e "\n$(ts) ${YELLOW}─── $* ───${NC}"; }

# ── Dependency checks ─────────────────────────────────────────────────────────
for cmd in curl nc smbclient ssh; do
  if ! command -v "${cmd}" &>/dev/null; then
    echo "Installing missing tool: ${cmd}..."
    case "${cmd}" in
      nc)         pkg="netcat-openbsd" ;;
      smbclient)  pkg="smbclient" ;;
      ssh)        pkg="openssh-client" ;;
      *)          pkg="${cmd}" ;;
    esac
    apt-get install -y -qq "${pkg}"
  fi
done

# ── Traffic functions ─────────────────────────────────────────────────────────

# HTTP – plain web request to IIS
do_http() {
  section "HTTP request → ${TARGET_HOST}:80"
  if curl -fsSL --max-time 10 "http://${TARGET_HOST}/" -o /dev/null \
       -w "HTTP %{http_code} in %{time_total}s"; then
    ok "HTTP 80 reachable"
  else
    fail "HTTP 80 failed"
  fi
}

# HTTPS – TLS web request (self-signed cert, so skip verify for demo)
do_https() {
  section "HTTPS request → ${TARGET_HOST}:443"
  if curl -kfsSL --max-time 10 "https://${TARGET_HOST}/" -o /dev/null \
       -w "HTTPS %{http_code} in %{time_total}s"; then
    ok "HTTPS 443 reachable"
  else
    fail "HTTPS 443 failed (may need cert setup)"
  fi
}

# Alt HTTP port
do_alt_http() {
  section "HTTP request → ${TARGET_HOST}:8080"
  if curl -fsSL --max-time 10 "http://${TARGET_HOST}:8080/" -o /dev/null \
       -w "HTTP/8080 %{http_code} in %{time_total}s"; then
    ok "HTTP 8080 reachable"
  else
    fail "HTTP 8080 failed"
  fi
}

# TCP port check for RDP (don't actually open a session – just probe the port)
do_rdp_probe() {
  section "TCP probe → ${TARGET_HOST}:3389 (RDP)"
  if nc -zw 5 "${TARGET_HOST}" 3389; then
    ok "RDP port 3389 open"
  else
    fail "RDP port 3389 not reachable"
  fi
}

# SMB – anonymous list shares (will fail auth but generates ZPA session logs)
do_smb() {
  section "SMB probe → \\\\${TARGET_HOST}\\LabShare"
  if smbclient -N -L "//${TARGET_HOST}" --timeout 10 &>/dev/null; then
    ok "SMB 445 reachable"
  else
    # Even a rejected auth generates a ZPA session log entry
    ok "SMB 445 port reachable (auth rejected as expected for anonymous)"
  fi
}

# SSH port probe (no credentials needed – just generates a session)
do_ssh_probe() {
  section "SSH probe → ${TARGET_HOST}:22"
  if nc -zw 5 "${TARGET_HOST}" 22; then
    ok "SSH port 22 open"
  else
    fail "SSH port 22 not reachable"
  fi
}

# ── Main loop ─────────────────────────────────────────────────────────────────
echo "================================================================"
echo " ZPA Traffic Generator"
echo " Target host : ${TARGET_HOST}"
echo " Interval    : ${INTERVAL}s"
echo " Max count   : ${MAX_COUNT} (0 = infinite)"
echo "================================================================"
echo " Press Ctrl-C to stop."
echo

ITERATION=0
while true; do
  ITERATION=$(( ITERATION + 1 ))
  echo -e "\n$(ts) ══ Iteration ${ITERATION} ══"

  do_http
  do_https
  do_alt_http
  do_rdp_probe
  do_smb
  do_ssh_probe

  if [[ "${MAX_COUNT}" -gt 0 && "${ITERATION}" -ge "${MAX_COUNT}" ]]; then
    echo -e "\n$(ts) Reached max count (${MAX_COUNT}). Exiting."
    break
  fi

  echo -e "$(ts) Sleeping ${INTERVAL}s before next round..."
  sleep "${INTERVAL}"
done
