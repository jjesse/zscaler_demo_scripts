#!/usr/bin/env bash
# =============================================================================
# demo_zia_blocks.sh
# Demonstrates ZIA threat protection and URL-category blocking by attempting
# to reach:
#
#   1. Known-bad / threat-intelligence URLs (malware, phishing, C2 tests)
#   2. Sites in categories typically blocked by corporate ZIA policy
#      (gambling, anonymizers, etc.)
#
# Every attempt that ZIA blocks will either time out or return ZIA's
# block page (HTTP 200 from Zscaler with a "This site is blocked" body),
# depending on your tenant's block-page configuration.
#
# Safe test URLs used:
#   - EICAR standard test (http://www.eicar.org/download/eicar.com.txt)
#     The EICAR file is harmless; every security product categorises it as
#     malware for testing purposes.
#   - Zscaler security-test page (https://security.zscaler.com/)
#   - Additional sites in URL categories that enterprise ZIA policies block
#
# Run this on any machine with Zscaler Client Connector connected, or with
# the ZIA proxy configured.
#
# Usage:
#   bash demo_zia_blocks.sh                    # run once
#   bash demo_zia_blocks.sh --repeat 3         # repeat 3 times
#   bash demo_zia_blocks.sh --log /tmp/zia.log
# =============================================================================

set -euo pipefail

# ── Defaults ──────────────────────────────────────────────────────────────────
REPEAT=1
LOG_FILE="/tmp/zia_block_demo.log"
TIMEOUT=10

# ── Argument parsing ─────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --repeat)  REPEAT="$2";   shift 2 ;;
    --log)     LOG_FILE="$2"; shift 2 ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

# ── Colour helpers ────────────────────────────────────────────────────────────
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'
CYAN='\033[0;36m'; MAGENTA='\033[0;35m'; WHITE='\033[1;37m'; NC='\033[0m'

ts()    { date '+%Y-%m-%d %H:%M:%S'; }
banner() {
  echo ""
  echo -e "${CYAN}$(printf '=%.0s' {1..68})${NC}"
  echo -e "${CYAN}  $1${NC}"
  echo -e "${CYAN}$(printf '=%.0s' {1..68})${NC}"
}
sub_banner() { echo -e "\n${YELLOW}  ── $1 ──${NC}"; }

BLOCKED_COUNT=0
ALLOWED_COUNT=0

# ── Logging ───────────────────────────────────────────────────────────────────
log() {
  local level="$1"; shift
  local msg="$*"
  local line="[$(ts)] [${level}] ${msg}"
  echo "${line}" >> "${LOG_FILE}"
  case "${level}" in
    BLOCKED) echo -e "  ${GREEN}[BLOCKED]${NC} ${msg}" ;;
    ALLOWED) echo -e "  ${RED}[ALLOWED]${NC} ${msg}  ← check ZIA policy!" ;;
    INFO)    echo -e "  ${CYAN}[INFO]${NC}    ${msg}" ;;
    WARN)    echo -e "  ${YELLOW}[WARN]${NC}    ${msg}" ;;
  esac
}

# ── Test helpers ──────────────────────────────────────────────────────────────

# Returns true if the response body contains ZIA's block-page signature.
# NOTE: If you update these keywords, update the equivalent pattern in
#       scripts/windows/demo_zia_blocks.ps1 ($body -imatch "...") as well.
is_zia_block_page() {
  local body="$1"
  echo "${body}" | grep -qi "zscaler\|blocked by\|access denied\|this site is blocked\|security policy" 2>/dev/null
}

test_blocked_url() {
  local url="$1"
  local label="$2"
  log INFO "Attempting: ${label} → ${url}"

  local http_code body
  body=$(curl -sk --max-time "${TIMEOUT}" \
    -A "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36" \
    -w "\n__HTTP_CODE__%{http_code}" \
    "${url}" 2>/dev/null || true)

  http_code=$(echo "${body}" | grep -oP '(?<=__HTTP_CODE__)\d+' || echo "000")
  body=$(echo "${body}" | sed '/__HTTP_CODE__/d')

  if [[ "${http_code}" == "000" ]]; then
    # Connection timed out or refused – ZIA dropped it
    log BLOCKED "${label} → timed out / no connection (ZIA dropped the traffic) ✓"
    (( BLOCKED_COUNT++ )) || true
  elif is_zia_block_page "${body}"; then
    # ZIA returned its block page (HTTP 200 with block content)
    log BLOCKED "${label} → ZIA block page returned (HTTP ${http_code}) ✓"
    (( BLOCKED_COUNT++ )) || true
  else
    log ALLOWED "${label} → HTTP ${http_code} – traffic NOT blocked"
    (( ALLOWED_COUNT++ )) || true
  fi
}

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

# ── Main ──────────────────────────────────────────────────────────────────────
banner "ZIA Block Demo – Linux Client"

echo ""
echo -e "${WHITE}DEMO NARRATIVE:${NC}"
echo "  The following connections target URLs in threat and restricted"
echo "  categories. ZIA should intercept and block each one."
echo ""
echo "  GREEN [BLOCKED] = ZIA blocked the request as expected ✓"
echo "  RED   [ALLOWED] = ZIA did NOT block – check your ZIA policy"
echo ""
echo "  Log file: ${LOG_FILE}"
echo ""
log INFO "Starting ZIA block demo (${REPEAT} round(s))"
log INFO "Ensure Zscaler Client Connector is CONNECTED."

for round in $(seq 1 "${REPEAT}"); do
  banner "Round ${round} of ${REPEAT}"

  # ── 1. Threat Protection – Malware test ─────────────────────────────────────
  sub_banner "Threat Protection – Malware / Virus Test URLs"
  echo -e "  ${CYAN}These safe test URLs are categorised as 'Malware' by ZIA threat${NC}"
  echo -e "  ${CYAN}intelligence. No real malware is downloaded.${NC}"

  # EICAR standard antivirus test file (universally recognised as safe test)
  test_blocked_url \
    "http://www.eicar.org/download/eicar.com.txt" \
    "EICAR test file (malware category)"

  # Zscaler security test page – designed specifically for ZIA demos
  test_blocked_url \
    "https://security.zscaler.com/" \
    "Zscaler security test page"

  # Additional known-bad test host used in ZIA sandbox demos
  test_blocked_url \
    "http://malware.wicar.org/data/ms14_064_ole_not_xp.html" \
    "WICAR malware test page"

  # ── 2. Phishing / Social Engineering test ────────────────────────────────────
  sub_banner "Threat Protection – Phishing Test URLs"
  echo -e "  ${CYAN}Phishing simulation URLs (safe – used for security-awareness testing).${NC}"

  test_blocked_url \
    "https://testsafebrowsing.appspot.com/s/phishing.html" \
    "Google Safe Browsing phishing test"

  test_blocked_url \
    "https://testsafebrowsing.appspot.com/s/malware.html" \
    "Google Safe Browsing malware test"

  # ── 3. URL Filtering – Gambling category ────────────────────────────────────
  sub_banner "URL Filtering – Gambling (blocked category)"
  echo -e "  ${CYAN}Gambling sites are blocked by default in enterprise ZIA policies.${NC}"

  test_blocked_url \
    "https://www.bet365.com" \
    "Gambling – bet365.com"

  test_blocked_url \
    "https://www.draftkings.com" \
    "Gambling – draftkings.com"

  # ── 4. URL Filtering – Anonymizer / Proxy category ──────────────────────────
  sub_banner "URL Filtering – Anonymizers & Proxies (blocked category)"
  echo -e "  ${CYAN}Anonymizer tools are blocked to prevent policy bypass.${NC}"

  test_blocked_url \
    "https://www.hidemyass.com" \
    "Anonymizer – hidemyass.com"

  test_blocked_url \
    "https://www.anonymouse.org" \
    "Anonymizer – anonymouse.org"

  # ── 5. URL Filtering – Peer-to-Peer category ────────────────────────────────
  sub_banner "URL Filtering – Peer-to-Peer / Torrents (blocked category)"
  echo -e "  ${CYAN}P2P sites are commonly blocked to protect bandwidth and IP exposure.${NC}"

  test_blocked_url \
    "https://www.thepiratebay.org" \
    "P2P/Torrent – thepiratebay.org"

  if [[ "${round}" -lt "${REPEAT}" ]]; then
    echo ""
    log INFO "Waiting 3 seconds before next round..."
    sleep 3
  fi
done

# ── Summary ───────────────────────────────────────────────────────────────────
banner "ZIA Block Demo Complete"
echo ""
echo -e "  ${WHITE}BLOCKED (expected / desired) : ${GREEN}${BLOCKED_COUNT}${NC}"
if [[ "${ALLOWED_COUNT}" -gt 0 ]]; then
  echo -e "  ${WHITE}ALLOWED (unexpected)         : ${RED}${ALLOWED_COUNT}${NC}"
else
  echo -e "  ${WHITE}ALLOWED (unexpected)         : ${GREEN}${ALLOWED_COUNT}${NC}"
fi
echo ""
echo -e "  ${WHITE}Full log: ${LOG_FILE}${NC}"
echo ""
echo -e "  ${CYAN}NEXT STEP: Open the ZIA Admin Portal → Analytics → Web Insights${NC}"
echo -e "  ${CYAN}Filter by this machine's IP or user to see all block events.${NC}"
echo -e "  ${CYAN}Each blocked URL appears with category, threat name, and action.${NC}"
echo ""

if [[ "${ALLOWED_COUNT}" -gt 0 ]]; then
  echo -e "  ${RED}ACTION REQUIRED: ${ALLOWED_COUNT} URL(s) were NOT blocked.${NC}"
  echo -e "  ${RED}Review your ZIA URL-Filtering and Threat Protection policies.${NC}"
  echo ""
fi
