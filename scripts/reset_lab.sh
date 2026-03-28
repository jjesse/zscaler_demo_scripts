#!/usr/bin/env bash
# =============================================================================
# reset_lab.sh – Master lab-reset script for the ZPA / ZIA / ZDX demo
#
# Run this between demo sessions to restore the lab to a clean, known-good
# baseline.  Use it before each customer meeting or after the ZDX "poor score"
# simulation to ensure dashboards and services are in the right state.
#
# Usage:
#   sudo bash scripts/reset_lab.sh            # full reset (all products)
#   sudo bash scripts/reset_lab.sh --zpa      # ZPA only
#   sudo bash scripts/reset_lab.sh --zia      # ZIA only
#   sudo bash scripts/reset_lab.sh --zdx      # ZDX only
# =============================================================================

set -euo pipefail

# ── Colour helpers ────────────────────────────────────────────────────────────
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

ts()      { date '+%H:%M:%S'; }
ok()      { echo -e "$(ts) ${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "$(ts) ${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "$(ts) ${RED}[ERROR]${NC} $*"; }
section() { echo -e "\n$(ts) ${CYAN}━━━ $* ━━━${NC}"; }

# ── Root check ────────────────────────────────────────────────────────────────
if [[ "${EUID}" -ne 0 ]]; then
  error "This script must be run as root (sudo bash $0)"
  exit 1
fi

# ── Helper: kill all processes matching a pattern (using pgrep + kill) ────────
kill_matching() {
  local pattern="$1"
  local label="${2:-${pattern}}"
  local pids
  # pgrep exits non-zero when no match – treat that as "nothing to kill"
  pids=$(pgrep -f "${pattern}" 2>/dev/null || true)
  if [[ -n "${pids}" ]]; then
    echo "${pids}" | while IFS= read -r pid; do
      [[ -n "$pid" ]] && kill "$pid" 2>/dev/null || true
    done
    ok "Stopped: ${label}"
  fi
}

# ── Helper: free a TCP port by killing the listening process ──────────────────
free_port() {
  local port="$1"
  local pids
  pids=$(lsof -ti tcp:"${port}" 2>/dev/null || true)
  if [[ -n "${pids}" ]]; then
    echo "${pids}" | while IFS= read -r pid; do
      [[ -n "$pid" ]] && kill "$pid" 2>/dev/null || true
    done
    ok "Freed port ${port}"
  fi
}

# ── Parse arguments ───────────────────────────────────────────────────────────
RESET_ZPA=false
RESET_ZIA=false
RESET_ZDX=false
RESET_ALL=true

while [[ $# -gt 0 ]]; do
  case "$1" in
    --zpa) RESET_ZPA=true; RESET_ALL=false; shift ;;
    --zia) RESET_ZIA=true; RESET_ALL=false; shift ;;
    --zdx) RESET_ZDX=true; RESET_ALL=false; shift ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

if [[ "$RESET_ALL" == "true" ]]; then
  RESET_ZPA=true
  RESET_ZIA=true
  RESET_ZDX=true
fi

echo ""
echo -e "${BOLD}${CYAN}============================================================${NC}"
echo -e "${BOLD}${CYAN} Zscaler Demo Lab – Reset Script${NC}"
echo -e "${BOLD}${CYAN}============================================================${NC}"
echo ""

# ── ZPA Reset ─────────────────────────────────────────────────────────────────
if [[ "$RESET_ZPA" == "true" ]]; then
  section "ZPA – Reset App Discovery Demo"

  # Stop the App Discovery demo helper and traffic generator
  kill_matching "demo_discovered_apps" "demo_discovered_apps.sh"
  kill_matching "generate_zpa_traffic" "ZPA traffic generator"

  # Free well-known App Discovery demo ports
  for port in 5000 6379 8888 9200 9090; do
    free_port "${port}"
  done

  # Verify ZPA Connector is still running
  if systemctl is-active --quiet zpa-connector 2>/dev/null; then
    ok "zpa-connector service is active"
  else
    warn "zpa-connector is not running. Start with: systemctl start zpa-connector"
  fi
fi

# ── ZIA Reset ─────────────────────────────────────────────────────────────────
if [[ "$RESET_ZIA" == "true" ]]; then
  section "ZIA – Reset Traffic Generator and Logs"

  kill_matching "generate_zia_traffic" "ZIA traffic generator"
  kill_matching "demo_url_filtering"   "ZIA URL filtering demo"

  # Clear demo log files
  for logfile in /tmp/zia_block_demo.log /tmp/zia_demo.log; do
    if [[ -f "$logfile" ]]; then
      rm -f "$logfile"
      ok "Removed $logfile"
    fi
  done

  ok "ZIA reset complete"
fi

# ── ZDX Reset ─────────────────────────────────────────────────────────────────
if [[ "$RESET_ZDX" == "true" ]]; then
  section "ZDX – Restore Good Score Baseline"

  # Stop any running ZDX simulation and CPU stress tools
  kill_matching "demo_zdx_scores" "ZDX score simulation"
  kill_matching "stress-ng"       "stress-ng CPU load"

  # Brief pause to let load drop before sampling
  sleep 2

  # Report current system load
  load=$(uptime | awk -F'load average: ' '{print $2}' | cut -d',' -f1 | tr -d ' ')
  cpu_cores=$(nproc 2>/dev/null || echo 1)
  ok "Current load average: ${load} (${cpu_cores} cores)"

  # Run the good-score baseline (3 probe rounds, background)
  SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
  ZDX_SCRIPT="${SCRIPT_DIR}/zdx/linux/demo_zdx_scores.sh"
  if [[ -f "${ZDX_SCRIPT}" ]]; then
    bash "${ZDX_SCRIPT}" --scenario good --count 3 &>/dev/null &
    ok "Started ZDX good-score baseline (3 rounds in background)"
  else
    warn "ZDX script not found at ${ZDX_SCRIPT}"
    warn "Run manually: bash scripts/zdx/linux/demo_zdx_scores.sh --scenario good"
  fi
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${GREEN}============================================================${NC}"
echo -e "${BOLD}${GREEN} Lab Reset Complete${NC}"
echo -e "${BOLD}${GREEN}============================================================${NC}"
echo ""
echo -e "  ${BOLD}Pre-demo checklist:${NC}"
echo ""

if [[ "$RESET_ZDX" == "true" ]]; then
  echo "  • ZDX: Allow 5–10 min for the portal to reflect the restored score."
fi
if [[ "$RESET_ZPA" == "true" ]]; then
  echo "  • ZPA: Confirm App Connector shows 'Connected' in the ZPA portal."
  echo "    Pre-stage: sudo bash scripts/zpa/linux/generate_zpa_traffic.sh --count 5"
fi
if [[ "$RESET_ZIA" == "true" ]]; then
  echo "  • ZIA: Pre-populate dashboards (run 10 min before the meeting):"
  echo "    bash scripts/zia/linux/generate_zia_traffic.sh --count 2 &"
fi
echo ""
