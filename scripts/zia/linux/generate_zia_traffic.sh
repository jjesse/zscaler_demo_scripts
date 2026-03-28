#!/usr/bin/env bash
# =============================================================================
# generate_zia_traffic.sh – Continuous internet traffic generator for ZIA demo
#
# Sends HTTPS requests across multiple URL categories so ZIA Analytics
# dashboards and the Log Explorer are populated before or during a demo.
#
# Categories covered:
#   News, Social Media, Sports, Streaming/Entertainment, Business/Cloud,
#   Search Engines, Caution (social / time-wasting), Blocked (P2P/threat)
#
# Run as a normal user (no root required).  Ensure the Zscaler Client
# Connector is Connected (green icon) or a ZIA proxy is configured before
# running.
#
# Usage:
#   bash scripts/zia/linux/generate_zia_traffic.sh              # run until Ctrl-C
#   bash scripts/zia/linux/generate_zia_traffic.sh --count 5   # 5 rounds then exit
#   bash scripts/zia/linux/generate_zia_traffic.sh --interval 30 --count 10
#
# Environment Variables (override defaults):
#   INTERVAL  – seconds between request rounds (default: 30)
# =============================================================================
set -euo pipefail

# ── Defaults ──────────────────────────────────────────────────────────────────
INTERVAL="${INTERVAL:-30}"
MAX_COUNT=0   # 0 = run forever

# ── Argument parsing ─────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --count)    MAX_COUNT="$2";  shift 2 ;;
    --interval) INTERVAL="$2";   shift 2 ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

# ── Colour helpers ────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
NC='\033[0m'

ts()      { date '+%H:%M:%S'; }
info()    { echo -e "${CYAN}[$(ts)]${NC} $*"; }
allow()   { echo -e "  ${GREEN}[ALLOW]${NC}  $*"; }
blocked() { echo -e "  ${RED}[BLOCK]${NC}  $*"; }
warn()    { echo -e "  ${YELLOW}[WARN]${NC}   $*"; }

# ── Dependency check ──────────────────────────────────────────────────────────
if ! command -v curl &>/dev/null; then
  if command -v apt-get &>/dev/null; then
    echo "curl not found – installing..."
    apt-get install -y -qq curl || { echo "Failed to install curl. Please install it manually." >&2; exit 1; }
  else
    echo "curl is required but not installed. Please install it and retry." >&2
    exit 1
  fi
fi

# ── Traffic targets ───────────────────────────────────────────────────────────

# Allowed – news sites
NEWS_SITES=(
  "https://www.cnn.com"
  "https://www.bbc.co.uk"
  "https://www.reuters.com"
  "https://apnews.com"
  "https://www.npr.org"
  "https://www.theguardian.com"
)

# Allowed – social media (may be Warn in ZIA depending on policy)
SOCIAL_SITES=(
  "https://www.linkedin.com"
  "https://www.reddit.com"
  "https://twitter.com"
  "https://www.facebook.com"
  "https://www.instagram.com"
)

# Allowed – sports
SPORTS_SITES=(
  "https://www.espn.com"
  "https://www.nfl.com"
  "https://www.nba.com"
  "https://www.mlb.com"
  "https://bleacherreport.com"
)

# Allowed – streaming / entertainment
STREAMING_SITES=(
  "https://www.youtube.com"
  "https://www.twitch.tv"
  "https://www.spotify.com"
  "https://vimeo.com"
  "https://soundcloud.com"
)

# Allowed – business / productivity (these should always be Allow)
BUSINESS_SITES=(
  "https://www.zscaler.com"
  "https://www.microsoft.com"
  "https://www.google.com"
  "https://github.com"
  "https://www.wikipedia.org"
  "https://www.salesforce.com"
  "https://slack.com"
  "https://zoom.us"
  "https://www.atlassian.com"
  "https://docs.microsoft.com"
)

# Blocked – P2P / risky (expect curl to fail / get ZIA block page)
BLOCKED_SITES=(
  "https://www.bittorrent.com"
  "https://malware.wicar.org"
)

# ── Helper: make a request, report result ────────────────────────────────────
make_request() {
  local label="$1"
  local url="$2"
  local expected="$3"  # "allow", "warn", "block"

  local http_code
  http_code=$(curl -fsSL \
    --max-time 10 \
    --write-out "%{http_code}" \
    --output /dev/null \
    -A "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36" \
    "$url" 2>/dev/null || echo "000")

  case "$expected" in
    allow)
      if [[ "$http_code" =~ ^[23] ]]; then
        allow "$label → HTTP $http_code"
      else
        info  "$label → HTTP $http_code (may be blocked or unreachable)"
      fi
      ;;
    warn)
      warn  "$label → HTTP $http_code (Caution/Warn page expected in ZIA)"
      ;;
    block)
      if [[ "$http_code" == "000" || "$http_code" =~ ^[45] ]]; then
        blocked "$label → blocked/unreachable (HTTP $http_code) ✓"
      else
        warn    "$label → HTTP $http_code (expected block – check ZIA policy)"
      fi
      ;;
  esac
}

# ── Main loop ─────────────────────────────────────────────────────────────────
CYCLE=0

echo ""
echo -e "${CYAN}================================================================${NC}"
echo -e "${CYAN} ZIA Traffic Generator – Linux Client${NC}"
echo -e "${CYAN}================================================================${NC}"
echo -e "  Interval : ${INTERVAL}s between rounds"
echo -e "  Count    : $([ "${MAX_COUNT}" -eq 0 ] && echo 'infinite' || echo "${MAX_COUNT}")"
echo -e "${CYAN}================================================================${NC}"
echo ""
echo " Sends HTTPS requests across multiple URL categories so ZIA"
echo " Analytics dashboards and Log Explorer are populated for the demo."
echo ""
echo " Ensure Zscaler Client Connector is Connected (green icon)"
echo " or a ZIA PAC/proxy is configured before running."
echo ""
echo " Press Ctrl-C to stop."
echo ""

while true; do
  CYCLE=$((CYCLE + 1))
  echo -e "${BLUE}--- Cycle ${CYCLE} ($(date '+%Y-%m-%d %H:%M:%S')) ---${NC}"

  echo -e "${MAGENTA}  ── News ──${NC}"
  for site in "${NEWS_SITES[@]}"; do
    make_request "News" "$site" "allow"
    sleep 1
  done

  echo -e "${MAGENTA}  ── Social Media ──${NC}"
  for site in "${SOCIAL_SITES[@]}"; do
    make_request "SocialMedia" "$site" "warn"
    sleep 1
  done

  echo -e "${MAGENTA}  ── Sports ──${NC}"
  for site in "${SPORTS_SITES[@]}"; do
    make_request "Sports" "$site" "allow"
    sleep 1
  done

  echo -e "${MAGENTA}  ── Streaming ──${NC}"
  for site in "${STREAMING_SITES[@]}"; do
    make_request "Streaming" "$site" "allow"
    sleep 1
  done

  echo -e "${MAGENTA}  ── Business / Productivity ──${NC}"
  for site in "${BUSINESS_SITES[@]}"; do
    make_request "Business" "$site" "allow"
    sleep 1
  done

  echo -e "${MAGENTA}  ── Blocked (P2P / Threat) ──${NC}"
  for site in "${BLOCKED_SITES[@]}"; do
    make_request "Blocked" "$site" "block"
    sleep 2
  done

  echo ""
  info "Cycle ${CYCLE} complete."

  if [[ "${MAX_COUNT}" -gt 0 && "${CYCLE}" -ge "${MAX_COUNT}" ]]; then
    echo ""
    info "Reached max count (${MAX_COUNT}). Exiting."
    break
  fi

  info "Sleeping ${INTERVAL}s before next round..."
  sleep "${INTERVAL}"
done
