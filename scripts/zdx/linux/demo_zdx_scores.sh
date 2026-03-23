#!/usr/bin/env bash
# =============================================================================
# demo_zdx_scores.sh
# Simulates good and poor Zscaler Digital Experience (ZDX) scores on a Linux
# endpoint so the ZDX dashboard and score-trend graphs update live during a
# customer demo.
#
# ZDX continuously probes network path quality, DNS resolution, TCP connect
# time, TLS handshake time, and HTTP response time for monitored applications,
# then combines those signals with device-health metrics (CPU, RAM, Wi-Fi)
# into a ZDX Score (0-100).
#
# This script drives those same metrics into "good" or "poor" territory so
# the audience can see the ZDX score change live in the portal:
#
#   good    – lightweight probes, low latency, clean results.
#             Score typically stays >= 80 (green).
#
#   poor    – saturates CPU/RAM, runs large parallel downloads to introduce
#             congestion, and shows the resulting high latency / packet-loss
#             in probe output.  Score typically drops to < 40 (red).
#
#   restore – kills all background load processes and restores the machine
#             to a healthy state.
#
# NOTE: This script only measures and reports metrics that ZDX would observe.
#       The *actual* ZDX score update in the portal depends on the ZDX probe
#       cycle configured for your tenant (typically 1-5 minutes).
#
# Usage:
#   bash demo_zdx_scores.sh --scenario good              # run until Ctrl-C
#   bash demo_zdx_scores.sh --scenario good --count 5   # 5 rounds then exit
#   bash demo_zdx_scores.sh --scenario poor              # degrade experience
#   bash demo_zdx_scores.sh --scenario restore           # restore healthy state
#   bash demo_zdx_scores.sh --scenario poor --verbose    # extra detail
#
# Environment Variables (override defaults):
#   INTERVAL  – seconds between probe rounds in good mode (default: 30)
# =============================================================================

set -euo pipefail

# ── Defaults ──────────────────────────────────────────────────────────────────
SCENARIO="good"
INTERVAL="${INTERVAL:-30}"
MAX_COUNT=0    # 0 = run forever
VERBOSE=0

# ── Argument parsing ──────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --scenario) SCENARIO="${2,,}"; shift 2 ;;   # lowercase
    --count)    MAX_COUNT="$2";    shift 2 ;;
    --interval) INTERVAL="$2";     shift 2 ;;
    --verbose|-v) VERBOSE=1;       shift   ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

# ── Colour helpers ────────────────────────────────────────────────────────────
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'
CYAN='\033[0;36m';  MAGENTA='\033[0;35m'; GRAY='\033[0;37m'
ORANGE='\033[0;33m'; NC='\033[0m'

ts()      { date '+%Y-%m-%d %H:%M:%S'; }
good()    { echo -e "$(ts) ${GREEN}[GOOD]${NC}    $*"; }
poor()    { echo -e "$(ts) ${RED}[POOR]${NC}    $*"; }
info()    { echo -e "$(ts) ${CYAN}[INFO]${NC}    $*"; }
warn()    { echo -e "$(ts) ${YELLOW}[WARN]${NC}    $*"; }
section() { echo -e "\n$(ts) ${MAGENTA}─── $* ───${NC}"; }

# ── Dependency check ──────────────────────────────────────────────────────────
for dep in curl dig ping; do
  if ! command -v "$dep" &>/dev/null; then
    if command -v apt-get &>/dev/null; then
      pkg=$( [[ "$dep" == "dig" ]] && echo "dnsutils" || echo "$dep" )
      warn "$dep not found – attempting apt-get install $pkg ..."
      apt-get install -y -qq "$pkg" 2>/dev/null || true
    fi
    if ! command -v "$dep" &>/dev/null; then
      warn "$dep is not available; some probes will be skipped."
    fi
  fi
done

# ── Monitored application endpoints (mirrors typical ZDX probe targets) ───────
declare -A APP_PROBES
APP_NAMES=(
  "Microsoft 365 (Exchange)"
  "Microsoft Teams"
  "Zoom"
  "Salesforce"
  "Google Workspace"
)
APP_URLS=(
  "https://outlook.office365.com"
  "https://teams.microsoft.com"
  "https://zoom.us"
  "https://login.salesforce.com"
  "https://workspace.google.com"
)

# ── Probe a single application endpoint ──────────────────────────────────────
probe_app() {
  local name="$1"
  local url="$2"
  local host
  host=$(echo "$url" | sed -E 's|https?://([^/]+).*|\1|')

  # DNS resolution time
  local dns_ms=9999
  if command -v dig &>/dev/null; then
    dns_ms=$(dig +time=5 +tries=1 "$host" 2>/dev/null |
             grep "Query time" | awk '{print $4}')
    dns_ms="${dns_ms:-9999}"
  fi

  # TCP connect time (port 443) using curl's timing variables
  local tcp_ms=9999
  local tls_ms=9999
  local http_ms=9999
  local status=0
  if command -v curl &>/dev/null; then
    local timing
    timing=$(curl -sk -o /dev/null \
      --connect-timeout 8 --max-time 15 \
      -A "ZDX-Demo/1.0 (Linux)" \
      -w "%{time_connect}|%{time_appconnect}|%{time_total}|%{http_code}" \
      "$url" 2>/dev/null || echo "9.999|9.999|9.999|000")
    IFS='|' read -r t_connect t_appconnect t_total http_code <<< "$timing"
    tcp_ms=$(echo "$t_connect * 1000" | bc 2>/dev/null | cut -d'.' -f1)
    tls_ms=$(echo "($t_appconnect - $t_connect) * 1000" | bc 2>/dev/null | cut -d'.' -f1)
    http_ms=$(echo "$t_total * 1000" | bc 2>/dev/null | cut -d'.' -f1)
    status="${http_code:-0}"
    tcp_ms="${tcp_ms:-9999}"
    tls_ms="${tls_ms:-9999}"
    http_ms="${http_ms:-9999}"
  fi

  # Estimate ZDX score contribution
  local score=100
  [[ "$dns_ms"  -gt 500  ]] && score=$((score - 30)) || [[ "$dns_ms"  -gt 100 ]] && score=$((score - 10)) || true
  [[ "$tcp_ms"  -gt 800  ]] && score=$((score - 30)) || [[ "$tcp_ms"  -gt 200 ]] && score=$((score - 10)) || true
  [[ "$http_ms" -gt 2000 ]] && score=$((score - 30)) || [[ "$http_ms" -gt 500 ]] && score=$((score - 10)) || true
  [[ "$score" -lt 0 ]] && score=0

  local label color
  if   [[ "$score" -ge 80 ]]; then label="GOOD ($score)";     color="$GREEN"
  elif [[ "$score" -ge 60 ]]; then label="FAIR ($score)";     color="$YELLOW"
  elif [[ "$score" -ge 40 ]]; then label="DEGRADED ($score)"; color="$ORANGE"
  else                              label="POOR ($score)";     color="$RED"
  fi

  printf "${color}  %-35s DNS:%4sms  TCP:%5sms  HTTP:%6sms  Score: %s${NC}\n" \
    "$name" "$dns_ms" "$tcp_ms" "$http_ms" "$label"
}

# ── Device health snapshot ────────────────────────────────────────────────────
show_device_health() {
  section "Device Health (ZDX Device Score inputs)"

  # CPU (1-second sample using /proc/stat for reliability)
  local cpu_used=0
  if [[ -r /proc/stat ]]; then
    local s1 s2
    s1=$(awk '/^cpu /{print $2,$3,$4,$5,$6,$7,$8,$9}' /proc/stat)
    sleep 1
    s2=$(awk '/^cpu /{print $2,$3,$4,$5,$6,$7,$8,$9}' /proc/stat)
    read -r u1 n1 sy1 id1 io1 ir1 so1 st1 <<< "$s1"
    read -r u2 n2 sy2 id2 io2 ir2 so2 st2 <<< "$s2"
    local total1=$(( u1+n1+sy1+id1+io1+ir1+so1+st1 ))
    local total2=$(( u2+n2+sy2+id2+io2+ir2+so2+st2 ))
    local diff_total=$(( total2 - total1 ))
    local diff_idle=$(( id2 - id1 ))
    [[ "$diff_total" -gt 0 ]] && cpu_used=$(( 100 * (diff_total - diff_idle) / diff_total ))
  fi
  local cpu_color="$GREEN"
  [[ "$cpu_used" -ge 60 ]] && cpu_color="$YELLOW"
  [[ "$cpu_used" -ge 80 ]] && cpu_color="$RED"
  echo -e "  ${cpu_color}CPU Usage       : ${cpu_used}%${NC}"

  # RAM
  local ram_pct=0
  if command -v free &>/dev/null; then
    ram_pct=$(free | awk '/^Mem:/{printf "%.0f", ($3/$2)*100}')
  fi
  local ram_color="$GREEN"
  [[ "$ram_pct" -ge 70 ]] && ram_color="$YELLOW"
  [[ "$ram_pct" -ge 85 ]] && ram_color="$RED"
  echo -e "  ${ram_color}RAM Usage       : ${ram_pct}%${NC}"

  # Wi-Fi signal
  local wifi_sig="(not available)"
  if command -v iwconfig &>/dev/null 2>/dev/null; then
    wifi_sig=$(iwconfig 2>/dev/null | grep "Signal level" |
               sed -E 's/.*Signal level=([^ ]+).*/\1/' | head -1)
    [[ -z "$wifi_sig" ]] && wifi_sig="(wired / not available)"
  fi
  echo -e "  ${CYAN}Wi-Fi Signal    : ${wifi_sig}${NC}"

  # ZCC process check
  local zcc_procs=0
  zcc_procs=$(ps aux 2>/dev/null | grep -iE "zscaler|zsaservice|zsatunnel" | grep -v grep | wc -l | tr -d ' ' || echo 0)
  zcc_procs=$(( zcc_procs + 0 ))   # coerce to integer
  local zcc_color="$GREEN"
  [[ "$zcc_procs" -eq 0 ]] && zcc_color="$RED"
  echo -e "  ${zcc_color}ZCC Processes   : ${zcc_procs} running${NC}"
}

# ── Packet-loss probe ─────────────────────────────────────────────────────────
show_packet_loss() {
  section "Packet Loss & Latency (ZDX Network Score inputs)"
  local targets=("8.8.8.8" "1.1.1.1" "208.67.222.222")
  for target in "${targets[@]}"; do
    if command -v ping &>/dev/null; then
      local ping_out
      ping_out=$(ping -c 10 -W 2 "$target" 2>/dev/null || true)
      local loss avg_ms
      loss=$(echo "$ping_out" | grep -oP '\d+(?=% packet loss)' || echo 100)
      avg_ms=$(echo "$ping_out" | grep -oP 'rtt min/avg.*= [\d.]+/\K[\d.]+' || echo 9999)
      avg_ms=$(printf "%.0f" "${avg_ms:-9999}")

      local color="$GREEN"
      [[ "$loss" -gt 2 || "$avg_ms" -gt 150 ]] && color="$YELLOW"
      [[ "$loss" -gt 5 || "$avg_ms" -gt 300 ]] && color="$RED"
      printf "${color}  %-15s  Avg:%6sms  Loss:%3s%%${NC}\n" "$target" "$avg_ms" "$loss"
    else
      echo -e "  ${GRAY}ping not available – skipping packet-loss probe${NC}"
      break
    fi
  done
}

# ── Good scenario ─────────────────────────────────────────────────────────────
run_good() {
  echo ""
  echo -e "${GREEN}================================================================${NC}"
  echo -e "${GREEN} ZDX Demo – GOOD Score Scenario${NC}"
  echo -e "${GREEN}================================================================${NC}"
  echo ""
  echo -e "${GREEN} This scenario simulates a healthy endpoint.${NC}"
  echo -e "${GREEN} Expected ZDX Score: 80-100 (GREEN).${NC}"
  echo ""
  echo -e "${CYAN} Tip: Run this 10 minutes before the demo to populate${NC}"
  echo -e "${CYAN}      score-trend history in the ZDX portal.${NC}"
  echo ""
  echo -e "${GRAY} Press Ctrl-C to stop.${NC}"
  echo ""

  local iter=0
  while true; do
    iter=$(( iter + 1 ))
    echo ""
    echo -e "$(ts) ${GREEN}══ Round ${iter} ══${NC}"

    show_device_health

    section "Application Probes (ZDX App Score inputs)"
    for i in "${!APP_NAMES[@]}"; do
      probe_app "${APP_NAMES[$i]}" "${APP_URLS[$i]}"
      sleep 0.5
    done

    show_packet_loss

    if [[ "$MAX_COUNT" -gt 0 && "$iter" -ge "$MAX_COUNT" ]]; then
      echo ""
      info "Reached max count (${MAX_COUNT}). Exiting."
      break
    fi

    echo ""
    info "Sleeping ${INTERVAL}s before next round..."
    sleep "${INTERVAL}"
  done
}

# ── Poor scenario ─────────────────────────────────────────────────────────────
ZDX_DEMO_PID_FILE="/tmp/zdx_demo_pids.txt"

run_poor() {
  echo ""
  echo -e "${RED}================================================================${NC}"
  echo -e "${RED} ZDX Demo – POOR Score Scenario${NC}"
  echo -e "${RED}================================================================${NC}"
  echo ""
  echo -e "${RED} This scenario simulates a degraded endpoint.${NC}"
  echo -e "${RED} Expected ZDX Score: < 40 (RED).${NC}"
  echo ""
  echo -e "${YELLOW} What this script does:${NC}"
  echo -e "${YELLOW}   1. Saturates CPU with background worker loops${NC}"
  echo -e "${YELLOW}   2. Allocates large memory buffers to pressure RAM${NC}"
  echo -e "${YELLOW}   3. Runs parallel large downloads to congest bandwidth${NC}"
  echo -e "${YELLOW}   4. Measures and displays degraded probe results${NC}"
  echo ""
  echo -e "${CYAN} Watch the ZDX portal — the score will drop within${NC}"
  echo -e "${CYAN} the next probe cycle (1-5 minutes).${NC}"
  echo ""
  echo -e "${GRAY} Run: bash demo_zdx_scores.sh --scenario restore  when done.${NC}"
  echo ""

  # Clean up any leftover PIDs from a previous run
  [[ -f "$ZDX_DEMO_PID_FILE" ]] && rm -f "$ZDX_DEMO_PID_FILE"
  touch "$ZDX_DEMO_PID_FILE"

  # ── Step 1: CPU saturation ──────────────────────────────────────────────────
  info "Starting CPU saturation workers..."
  local cpu_cores
  cpu_cores=$(nproc 2>/dev/null || echo 2)
  local load_workers=$(( cpu_cores > 1 ? cpu_cores - 1 : 1 ))
  for (( i=0; i<load_workers; i++ )); do
    ( while true; do echo "scale=5000; a(1)*4" | bc -l &>/dev/null; done ) &
    echo "$!" >> "$ZDX_DEMO_PID_FILE"
  done
  info "Started ${load_workers} CPU workers (PIDs saved to $ZDX_DEMO_PID_FILE)"

  # ── Step 2: Memory pressure ─────────────────────────────────────────────────
  info "Allocating memory buffers to increase RAM pressure..."
  (
    # Allocate ~512 MB using dd to /dev/null (forces page allocation)
    dd if=/dev/urandom bs=1M count=512 2>/dev/null | cat > /dev/null &
    echo "$!" >> "$ZDX_DEMO_PID_FILE"
  ) || true

  # ── Step 3: Bandwidth saturation ───────────────────────────────────────────
  info "Starting bandwidth saturation (parallel large downloads)..."
  local test_urls=(
    "https://speed.hetzner.de/100MB.bin"
    "https://proof.ovh.net/files/100Mb.dat"
  )
  for url in "${test_urls[@]}"; do
    (
      curl -sk -o /dev/null --max-time 300 \
        -A "ZDX-Demo/1.0 (Linux)" "$url" 2>/dev/null || true
    ) &
    echo "$!" >> "$ZDX_DEMO_PID_FILE"
  done
  info "Bandwidth saturation started. Waiting 10s for congestion to develop..."
  sleep 10

  # ── Step 4: Measure and display degraded probe results ─────────────────────
  echo ""
  echo -e "$(ts) ${RED}Measuring degraded probe results...${NC}"

  show_device_health

  section "Application Probes (expected: POOR scores)"
  for i in "${!APP_NAMES[@]}"; do
    probe_app "${APP_NAMES[$i]}" "${APP_URLS[$i]}"
    sleep 0.5
  done

  show_packet_loss

  echo ""
  echo -e "${RED}================================================================${NC}"
  echo -e "${RED} Poor-score scenario running. Background load is active.${NC}"
  echo -e "${RED} Check the ZDX portal in 2-5 minutes to see the score drop.${NC}"
  echo -e "${RED} Run: bash demo_zdx_scores.sh --scenario restore  when done.${NC}"
  echo -e "${RED}================================================================${NC}"
  echo ""
}

# ── Restore scenario ──────────────────────────────────────────────────────────
run_restore() {
  echo ""
  echo -e "${CYAN}================================================================${NC}"
  echo -e "${CYAN} ZDX Demo – Restore (Healthy State)${NC}"
  echo -e "${CYAN}================================================================${NC}"
  echo ""

  if [[ -f "$ZDX_DEMO_PID_FILE" ]]; then
    while IFS= read -r pid; do
      if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
        kill "$pid" 2>/dev/null || true
        info "Stopped process $pid"
      fi
    done < "$ZDX_DEMO_PID_FILE"
    rm -f "$ZDX_DEMO_PID_FILE"
    info "PID file removed."
  else
    warn "No PID file found at $ZDX_DEMO_PID_FILE — nothing to clean up."
  fi

  # Clean up temp files
  rm -f /tmp/*.bin /tmp/*.dat 2>/dev/null || true
  info "Temporary download files cleaned up."

  info "Waiting 15s for CPU and RAM to stabilise..."
  sleep 15

  echo ""
  echo -e "$(ts) ${CYAN}Verifying restored health:${NC}"
  show_device_health

  section "Application Probes (expected: GOOD scores)"
  for i in "${!APP_NAMES[@]}"; do
    probe_app "${APP_NAMES[$i]}" "${APP_URLS[$i]}"
    sleep 0.5
  done

  show_packet_loss

  echo ""
  echo -e "${GREEN}================================================================${NC}"
  echo -e "${GREEN} Endpoint restored to healthy state.${NC}"
  echo -e "${GREEN} ZDX score will recover within the next probe cycle (1-5 min).${NC}"
  echo -e "${GREEN}================================================================${NC}"
  echo ""
}

# ── Entry point ───────────────────────────────────────────────────────────────
echo ""
echo -e "${CYAN}================================================================${NC}"
echo -e "${CYAN} ZDX Score Demo Script – Linux Client${NC}"
echo -e "${CYAN}================================================================${NC}"
echo -e "  Scenario : ${SCENARIO}"
echo -e "  Interval : ${INTERVAL}s  |  Count: $([ "$MAX_COUNT" -eq 0 ] && echo 'infinite' || echo "$MAX_COUNT")"
echo -e "${CYAN}================================================================${NC}"
echo ""

case "$SCENARIO" in
  good)    run_good    ;;
  poor)    run_poor    ;;
  restore) run_restore ;;
  *)
    echo "Unknown scenario: $SCENARIO. Use: good | poor | restore" >&2
    exit 1
    ;;
esac
