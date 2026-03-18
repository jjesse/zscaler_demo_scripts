#!/usr/bin/env bash
# =============================================================================
# demo_url_filtering.sh – URL filtering & threat protection demo (Linux)
#
# Demonstrates ZIA URL filtering, threat protection, and the block page.
# Run from the Ubuntu client machine with ZIA proxy configured.
#
# Usage:
#   bash scripts/zia/linux/demo_url_filtering.sh [--quiet]
# =============================================================================
set -euo pipefail

QUIET=false
[[ "${1:-}" == "--quiet" ]] && QUIET=true

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

print()   { echo -e "$*"; }
info()    { echo -e "${CYAN}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[ALLOW]${NC} $*"; }
blocked() { echo -e "${RED}[BLOCK]${NC} $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
sep()     { echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"; }
pause()   { [[ "$QUIET" == "false" ]] && read -rp "  ↵  Press Enter to continue..." _; }

# ---------------------------------------------------------------------------
# Helper: test a URL and print formatted result
# ---------------------------------------------------------------------------
test_url() {
    local label="$1"
    local url="$2"
    local expected="$3"   # allow | block | warn
    local description="$4"

    local response
    response=$(curl -fsSL \
        --max-time 10 \
        --write-out "HTTPSTATUS:%{http_code}" \
        --output /dev/null \
        "$url" 2>/dev/null || echo "HTTPSTATUS:000")

    local http_code
    http_code=$(echo "$response" | grep -o "HTTPSTATUS:[0-9]*" | cut -d: -f2)

    case "$expected" in
        allow)
            if [[ "$http_code" =~ ^[23] ]]; then
                success "ALLOWED  │ $label"
            else
                warn "EXPECTED ALLOW │ $label (HTTP $http_code) — check ZIA policy"
            fi
            ;;
        block)
            if [[ "$http_code" == "000" || "$http_code" =~ ^[45] ]]; then
                blocked "BLOCKED  │ $label"
            else
                warn "EXPECTED BLOCK │ $label (HTTP $http_code) — check ZIA policy"
            fi
            ;;
        warn)
            warn "CAUTION  │ $label (HTTP $http_code)"
            ;;
    esac

    [[ "$QUIET" == "false" ]] && info "  → URL: $url"
    [[ -n "$description" ]] && info "  → $description"
    echo ""
}

# ---------------------------------------------------------------------------
# Start
# ---------------------------------------------------------------------------
clear
print ""
print "${BOLD}╔══════════════════════════════════════════════════════╗${NC}"
print "${BOLD}║     ZIA URL Filtering & Threat Protection Demo       ║${NC}"
print "${BOLD}╚══════════════════════════════════════════════════════╝${NC}"
print ""
info "This script tests ZIA URL filtering, threat protection,"
info "and cloud app control by making HTTP requests through ZIA."
print ""
pause

# ---------------------------------------------------------------------------
# Scene 1: Verify ZIA is in the path
# ---------------------------------------------------------------------------
sep
print "${BOLD}Scene 1: Verify ZIA is in the path${NC}"
print ""
info "Checking ip.zscaler.com to confirm traffic routes through ZIA..."
print ""

ZIA_CHECK=$(curl -fsSL --max-time 15 "https://ip.zscaler.com" 2>/dev/null || echo "UNREACHABLE")
if echo "$ZIA_CHECK" | grep -qi "zscaler"; then
    success "Traffic confirmed routing through ZIA!"
    echo "$ZIA_CHECK" | grep -E "(Gateway|ZEN|Location)" | head -5 || true
else
    warn "Could not confirm ZIA routing. Ensure proxy settings are active."
    warn "Set: export https_proxy=http://gateway.<your-cloud>:80"
fi
print ""
pause

# ---------------------------------------------------------------------------
# Scene 2: Allowed – Business / Productivity Sites
# ---------------------------------------------------------------------------
sep
print "${BOLD}Scene 2: Allowed – Business & Productivity Sites${NC}"
print ""
info "Talking track: 'These are the sites your employees need every day."
info "ZIA inspects the traffic — even HTTPS — but allows access.'"
print ""

test_url "Microsoft.com"   "https://www.microsoft.com"   "allow" "Corporate productivity site — allowed by policy"
test_url "GitHub.com"      "https://github.com"           "allow" "Developer tool — allowed by policy"
test_url "Wikipedia.org"   "https://www.wikipedia.org"    "allow" "Reference site — allowed by policy"

pause

# ---------------------------------------------------------------------------
# Scene 3: Caution – Social Media
# ---------------------------------------------------------------------------
sep
print "${BOLD}Scene 3: Caution – Social Media (Warn page)${NC}"
print ""
info "Talking track: 'Social media is not blocked — but ZIA shows a caution"
info "page so users understand it may be monitored and is non-business use.'"
print ""

test_url "Reddit.com"     "https://www.reddit.com"    "warn" "Social networking — ZIA shows Warn/Caution page"
test_url "LinkedIn.com"   "https://www.linkedin.com"  "allow" "Professional network — allowed (business use)"

pause

# ---------------------------------------------------------------------------
# Scene 4: Blocked – P2P / Risky Categories
# ---------------------------------------------------------------------------
sep
print "${BOLD}Scene 4: Blocked – P2P & Risky Content${NC}"
print ""
info "Talking track: 'BitTorrent and P2P sites are blocked by policy."
info "The connection never leaves the machine — ZIA drops it in the cloud.'"
print ""

test_url "BitTorrent.com"       "https://www.bittorrent.com"  "block" "P2P / torrents — blocked by policy"
test_url "Piratebay (example)"  "https://thepiratebay.org"    "block" "P2P site — blocked by policy"

pause

# ---------------------------------------------------------------------------
# Scene 5: Threat Protection – Malware / Phishing
# ---------------------------------------------------------------------------
sep
print "${BOLD}Scene 5: Threat Protection – Malware & Phishing${NC}"
print ""
info "Talking track: 'ZIA has a real-time threat intelligence feed."
info "These test URLs are known-bad — ZIA blocks them before the first byte.'"
print ""

# EICAR test file (standard AV test — safe, always blocked by ZIA)
test_url "EICAR test file (HTTP)"   "http://malware.wicar.org/data/eicar.com"   "block" "EICAR test file — standard malware test, blocked by ZIA"
test_url "EICAR test file (HTTPS)"  "https://malware.wicar.org/data/eicar.com"  "block" "EICAR HTTPS — SSL-inspected and blocked"

pause

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
sep
print "${BOLD}Demo Complete${NC}"
print ""
info "Next steps for the customer:"
echo "  1. Open ZIA Admin Portal → Analytics → Web Insights"
echo "  2. Filter by this machine's user or IP"
echo "  3. Show ALLOW, WARN, and BLOCK events with full identity context"
echo "  4. Navigate to Analytics → Threat Insights for the malware block events"
print ""
info "Script completed successfully."
