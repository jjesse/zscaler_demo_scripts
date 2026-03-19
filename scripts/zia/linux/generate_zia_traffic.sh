#!/usr/bin/env bash
# =============================================================================
# generate_zia_traffic.sh – Continuous internet traffic generator for ZIA demo
#
# Sends a mix of allowed, warned, and blocked traffic through ZIA so that
# the Analytics dashboards are populated before or during the demo.
#
# Run as a normal user (no root required):
#   bash scripts/zia/linux/generate_zia_traffic.sh
#
# Runs indefinitely. Press Ctrl-C to stop.
# =============================================================================
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
NC='\033[0m'

info()    { echo -e "${CYAN}[$(date '+%H:%M:%S')]${NC} $*"; }
allow()   { echo -e "${GREEN}[ALLOW]${NC}  $*"; }
blocked() { echo -e "${RED}[BLOCK]${NC}  $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}   $*"; }

# ---------------------------------------------------------------------------
# Traffic targets
# ---------------------------------------------------------------------------
# Allowed – business / productivity sites
ALLOWED_SITES=(
    "https://www.zscaler.com"
    "https://www.microsoft.com"
    "https://www.google.com"
    "https://github.com"
    "https://www.wikipedia.org"
    "https://www.linkedin.com"
    "https://docs.microsoft.com"
)

# Caution / Warn – social media (ZIA shows a warn page)
CAUTION_SITES=(
    "https://www.reddit.com"
    "https://news.ycombinator.com"
)

# Block – P2P / risky sites (expect curl to fail / be blocked)
BLOCKED_SITES=(
    "https://www.bittorrent.com"
    "https://malware.wicar.org"
)

# ---------------------------------------------------------------------------
# Helper: make a request, report result, swallow errors
# ---------------------------------------------------------------------------
make_request() {
    local label="$1"
    local url="$2"
    local expected="$3"  # "allow", "warn", "block"

    local http_code
    http_code=$(curl -fsSL \
        --max-time 10 \
        --write-out "%{http_code}" \
        --output /dev/null \
        "$url" 2>/dev/null || echo "000")

    case "$expected" in
        allow)
            if [[ "$http_code" =~ ^[23] ]]; then
                allow "$label ($url) → HTTP $http_code"
            else
                info  "$label ($url) → HTTP $http_code (may be blocked or unreachable)"
            fi
            ;;
        warn)
            warn  "$label ($url) → HTTP $http_code (Caution page expected)"
            ;;
        block)
            if [[ "$http_code" == "000" || "$http_code" =~ ^[45] ]]; then
                blocked "$label ($url) → blocked/unreachable (HTTP $http_code)"
            else
                warn    "$label ($url) → HTTP $http_code (expected block)"
            fi
            ;;
    esac
}

# ---------------------------------------------------------------------------
# Main loop
# ---------------------------------------------------------------------------
CYCLE=0

info "=== ZIA Traffic Generator Started ==="
info "Traffic is flowing through ZIA. Press Ctrl-C to stop."
echo ""

while true; do
    CYCLE=$((CYCLE + 1))
    echo -e "${BLUE}--- Cycle ${CYCLE} ($(date '+%Y-%m-%d %H:%M:%S')) ---${NC}"

    # Allowed traffic
    for site in "${ALLOWED_SITES[@]}"; do
        make_request "Business" "$site" "allow"
        sleep 1
    done

    # Caution traffic
    for site in "${CAUTION_SITES[@]}"; do
        make_request "SocialMedia" "$site" "warn"
        sleep 1
    done

    # Blocked traffic
    for site in "${BLOCKED_SITES[@]}"; do
        make_request "Blocked" "$site" "block"
        sleep 2
    done

    echo ""
    info "Cycle ${CYCLE} complete. Sleeping 30 seconds..."
    sleep 30
done
