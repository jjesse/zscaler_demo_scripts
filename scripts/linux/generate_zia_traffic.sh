#!/usr/bin/env bash
# =============================================================================
# generate_zia_traffic.sh
# Generates HTTPS traffic to public internet destinations across multiple
# URL categories so ZIA dashboards, URL-Filtering reports, and Log Explorer
# stay populated during a demo.
#
# Categories covered:
#   News, Social Media, Sports, Streaming/Entertainment, Business/Cloud, Search
#
# Run this on the Ubuntu client (or any machine with Zscaler Client Connector
# or a Zscaler PAC/proxy configured).
#
# Usage:
#   bash generate_zia_traffic.sh              # runs until Ctrl-C
#   bash generate_zia_traffic.sh --count 5    # 5 rounds then exit
#   bash generate_zia_traffic.sh --interval 30 --count 10
#
# Environment Variables (override defaults):
#   INTERVAL  – seconds between request rounds (default: 15)
# =============================================================================

set -euo pipefail

# ── Defaults ──────────────────────────────────────────────────────────────────
INTERVAL="${INTERVAL:-15}"
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
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'
CYAN='\033[0;36m'; MAGENTA='\033[0;35m'; NC='\033[0m'

ts()      { date '+%Y-%m-%d %H:%M:%S'; }
ok()      { echo -e "$(ts) ${GREEN}[OK]${NC}    $*"; }
fail()    { echo -e "$(ts) ${RED}[SKIP]${NC}  $*"; }
section() { echo -e "\n$(ts) ${YELLOW}─── $* ───${NC}"; }
info()    { echo -e "$(ts) ${CYAN}[INFO]${NC}  $*"; }

# ── Dependency check ──────────────────────────────────────────────────────────
if ! command -v curl &>/dev/null; then
  if command -v apt-get &>/dev/null; then
    echo "Installing curl..."
    apt-get install -y -qq curl
  else
    echo "curl is required but not installed. Please install it and retry." >&2
    exit 1
  fi
fi

# ── URL lists by category ─────────────────────────────────────────────────────
NEWS_SITES=(
  "https://www.cnn.com"
  "https://www.bbc.co.uk"
  "https://www.reuters.com"
  "https://apnews.com"
  "https://www.npr.org"
  "https://www.theguardian.com"
)

SOCIAL_SITES=(
  "https://www.linkedin.com"
  "https://www.reddit.com"
  "https://twitter.com"
  "https://www.facebook.com"
  "https://www.instagram.com"
)

SPORTS_SITES=(
  "https://www.espn.com"
  "https://www.nfl.com"
  "https://www.nba.com"
  "https://www.mlb.com"
  "https://www.nhl.com"
  "https://bleacherreport.com"
)

STREAMING_SITES=(
  "https://www.youtube.com"
  "https://www.twitch.tv"
  "https://www.spotify.com"
  "https://vimeo.com"
  "https://soundcloud.com"
)

BUSINESS_SITES=(
  "https://www.microsoft.com"
  "https://www.salesforce.com"
  "https://slack.com"
  "https://zoom.us"
  "https://github.com"
  "https://www.atlassian.com"
  "https://www.google.com"
)

# ── Traffic function ──────────────────────────────────────────────────────────
fetch_site() {
  local url="$1"
  local category="$2"
  local http_code
  http_code=$(curl -sk -o /dev/null -w "%{http_code}" \
    --connect-timeout 8 \
    --max-time 12 \
    -A "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36" \
    "$url" 2>/dev/null || echo "000")

  if [[ "$http_code" != "000" && "$http_code" != "" ]]; then
    ok "[${category}] ${url} → HTTP ${http_code}"
  else
    fail "[${category}] ${url} → timeout/blocked (check ZIA policy or connectivity)"
  fi
}

visit_category() {
  local category="$1"
  shift
  local sites=("$@")
  section "Category: ${category}"
  for url in "${sites[@]}"; do
    fetch_site "$url" "$category"
    sleep 1
  done
}

# ── Main loop ─────────────────────────────────────────────────────────────────
echo ""
echo -e "${CYAN}================================================================${NC}"
echo -e "${CYAN} ZIA Traffic Generator – Linux Client${NC}"
echo -e "${CYAN}================================================================${NC}"
echo -e "  Interval : ${INTERVAL}s between rounds"
echo -e "  Count    : $([ "${MAX_COUNT}" -eq 0 ] && echo 'infinite' || echo "${MAX_COUNT}")"
echo -e "${CYAN}================================================================${NC}"
echo ""
echo " This script sends HTTPS requests to public sites in multiple"
echo " URL categories so ZIA URL-Filtering and Analytics dashboards"
echo " show real, categorised traffic during your demo."
echo ""
echo " Ensure Zscaler Client Connector is connected (or a ZIA proxy"
echo " is configured) before running."
echo ""
echo " Press Ctrl-C to stop."
echo ""

ITERATION=0
while true; do
  ITERATION=$(( ITERATION + 1 ))
  echo -e "\n$(ts) ${MAGENTA}══ Iteration ${ITERATION} ══${NC}"

  visit_category "News"         "${NEWS_SITES[@]}"
  visit_category "Social Media" "${SOCIAL_SITES[@]}"
  visit_category "Sports"       "${SPORTS_SITES[@]}"
  visit_category "Streaming"    "${STREAMING_SITES[@]}"
  visit_category "Business"     "${BUSINESS_SITES[@]}"

  if [[ "${MAX_COUNT}" -gt 0 && "${ITERATION}" -ge "${MAX_COUNT}" ]]; then
    echo -e "\n$(ts) Reached max count (${MAX_COUNT}). Exiting."
    break
  fi

  echo -e "\n$(ts) Sleeping ${INTERVAL}s before next round..."
  sleep "${INTERVAL}"
done
