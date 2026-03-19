#!/usr/bin/env bash
# demo_user_access.sh – ZPA Per-User Access Demo (Linux / Ubuntu client)
#
# Demonstrates how ZPA enforces granular, identity-aware access control by
# testing which resources are reachable for each user persona.
#
# This is the Linux companion to demo_user_access.ps1 and supports
# Act 1.5 of the ZPA Demo Guide: "Granular Per-User Access Control".
#
# Prerequisites:
#   - ZPA App Connector running on this machine OR
#     run from a Linux client with ZPA Client Connector installed.
#   - curl, nc (netcat), smbclient (optional) installed.
#
# Usage:
#   sudo bash demo_user_access.sh [--persona PERSONA] [--target IP] [--show-denied]
#
#   PERSONA choices: itadmin | engineer | contractor | hr
#
# Examples:
#   sudo bash demo_user_access.sh --persona itadmin
#   sudo bash demo_user_access.sh --persona contractor --show-denied
#   sudo bash demo_user_access.sh --persona hr

set -euo pipefail

# ── Defaults ──────────────────────────────────────────────────────────────────
TARGET_HOST="192.168.1.20"
LINUX_HOST="192.168.1.10"
PERSONA="itadmin"
SHOW_DENIED=false
LOG_FILE="/tmp/zpa_user_access_demo.log"
TCP_TIMEOUT=5

# ── Colours ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
WHITE='\033[1;37m'
RESET='\033[0m'

PASS_COUNT=0
FAIL_COUNT=0

# ── Arg parsing ───────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        --persona)    PERSONA="${2,,}"; shift 2 ;;
        --target)     TARGET_HOST="$2"; shift 2 ;;
        --linux-host) LINUX_HOST="$2";  shift 2 ;;
        --show-denied) SHOW_DENIED=true; shift ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

# ── Logging ───────────────────────────────────────────────────────────────────
log() {
    local level="$1"; shift
    local msg="$*"
    local ts
    ts=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$ts] [$level] $msg" >> "$LOG_FILE"
    case "$level" in
        PASS)    echo -e "  ${GREEN}[PASS]    $msg${RESET}" ;;
        FAIL)    echo -e "  ${RED}[FAIL]    $msg${RESET}" ;;
        BLOCKED) echo -e "  ${GREEN}[BLOCKED] $msg${RESET}" ;;
        ALLOWED) echo -e "  ${RED}[ALLOWED] $msg${RESET}" ;;
        INFO)    echo -e "  ${CYAN}[INFO]    $msg${RESET}" ;;
        WARN)    echo -e "  ${YELLOW}[WARN]    $msg${RESET}" ;;
    esac
}

banner() {
    echo ""
    echo -e "${CYAN}$(printf '=%.0s' {1..68})${RESET}"
    echo -e "${CYAN}  $1${RESET}"
    echo -e "${CYAN}$(printf '=%.0s' {1..68})${RESET}"
}

sub_banner() {
    echo ""
    echo -e "${YELLOW}  ── $1 ──${RESET}"
}

# ── Dependency check ──────────────────────────────────────────────────────────
check_deps() {
    local missing=()
    command -v curl >/dev/null 2>&1 || missing+=(curl)
    command -v nc   >/dev/null 2>&1 || missing+=(netcat-openbsd)
    if [[ ${#missing[@]} -gt 0 ]]; then
        log WARN "Missing tools: ${missing[*]}. Attempting to install..."
        if apt-get install -y -qq "${missing[@]}" 2>/dev/null; then
            log INFO "Dependencies installed successfully."
        else
            log WARN "Could not install ${missing[*]} automatically. Some tests may fail."
            log WARN "Run: sudo apt-get install -y ${missing[*]}"
        fi
    fi
}

# ── Test functions ────────────────────────────────────────────────────────────

test_http() {
    local url="$1"
    local app_name="$2"
    local should_allow="$3"   # true | false

    local http_code
    http_code=$(curl -sk -o /dev/null -w "%{http_code}" \
        --connect-timeout "$TCP_TIMEOUT" \
        --max-time $(( TCP_TIMEOUT + 3 )) \
        "$url" 2>/dev/null || echo "000")

    if [[ "$http_code" != "000" && "$http_code" != "" ]]; then
        # Connection reached server
        if [[ "$should_allow" == "true" ]]; then
            log PASS    "$app_name -> HTTP $http_code ✓ (expected ALLOW)"
            (( PASS_COUNT++ )) || true
        else
            log ALLOWED "$app_name -> HTTP $http_code UNEXPECTED – should be blocked!"
            (( FAIL_COUNT++ )) || true
        fi
    else
        # Connection failed / timed out
        if [[ "$should_allow" == "true" ]]; then
            log FAIL    "$app_name -> connection failed (expected ALLOW but was BLOCKED)"
            (( FAIL_COUNT++ )) || true
        else
            log BLOCKED "$app_name -> blocked as expected ✓"
            (( PASS_COUNT++ )) || true
        fi
    fi
}

test_tcp() {
    local host="$1"
    local port="$2"
    local app_name="$3"
    local should_allow="$4"

    if nc -z -w "$TCP_TIMEOUT" "$host" "$port" 2>/dev/null; then
        if [[ "$should_allow" == "true" ]]; then
            log PASS    "$app_name -> TCP ${host}:${port} open ✓ (expected ALLOW)"
            (( PASS_COUNT++ )) || true
        else
            log ALLOWED "$app_name -> TCP ${host}:${port} UNEXPECTED – should be blocked!"
            (( FAIL_COUNT++ )) || true
        fi
    else
        if [[ "$should_allow" == "true" ]]; then
            log FAIL    "$app_name -> TCP ${host}:${port} timed out (expected ALLOW but was BLOCKED)"
            (( FAIL_COUNT++ )) || true
        else
            log BLOCKED "$app_name -> blocked as expected ✓"
            (( PASS_COUNT++ )) || true
        fi
    fi
}

test_smb() {
    local share="$1"
    local app_name="$2"
    local should_allow="$3"

    if command -v smbclient >/dev/null 2>&1; then
        if smbclient -N "$share" -c "ls" >/dev/null 2>&1; then
            if [[ "$should_allow" == "true" ]]; then
                log PASS    "$app_name -> SMB $share listed ✓ (expected ALLOW)"
                (( PASS_COUNT++ )) || true
            else
                log ALLOWED "$app_name -> SMB $share UNEXPECTED – should be blocked!"
                (( FAIL_COUNT++ )) || true
            fi
        else
            if [[ "$should_allow" == "true" ]]; then
                log FAIL    "$app_name -> SMB $share failed (expected ALLOW but was BLOCKED)"
                (( FAIL_COUNT++ )) || true
            else
                log BLOCKED "$app_name -> blocked as expected ✓"
                (( PASS_COUNT++ )) || true
            fi
        fi
    else
        # Fall back to TCP 445 check
        test_tcp "$TARGET_HOST" 445 "$app_name (TCP 445 fallback)" "$should_allow"
    fi
}

# ── Persona runner ────────────────────────────────────────────────────────────

run_itadmin() {
    log INFO "Persona: IT Admin (bob.jones) | dept=IT | Policy: Allow-IT-Admins-Full"
    log INFO "Expected: Full access – WebApps, RDP, FileShare, SSH"

    if [[ "$SHOW_DENIED" == "false" ]]; then
        sub_banner "Resources IT Admin SHOULD reach"
        test_http "http://$TARGET_HOST/"       "Web Portal (HTTP 80)"    true
        test_http "http://$TARGET_HOST:8080/"  "Alt Web Portal (8080)"   true
        test_http "https://$TARGET_HOST/"      "Web Portal (HTTPS 443)"  true
        test_tcp  "$TARGET_HOST" 3389          "RDP (3389)"              true
        test_tcp  "$LINUX_HOST"  22            "SSH to Ubuntu (22)"      true
        test_smb  "//$TARGET_HOST/LabShare"    "SMB File Share"          true
    fi

    sub_banner "Resources IT Admin should NOT reach (always blocked)"
    test_http "http://$TARGET_HOST:9090/" "Shadow IT App (9090)"  false
    test_tcp  "$TARGET_HOST" 1433         "SQL Server (1433)"     false
    test_tcp  "$TARGET_HOST" 5432         "PostgreSQL (5432)"     false
    test_tcp  "$TARGET_HOST" 6379         "Redis (6379)"          false
}

run_engineer() {
    log INFO "Persona: Engineer (alice.smith) | dept=Engineering | Policy: Allow-Engineers-WebSSH"
    log INFO "Expected: Web + SSH only – NO RDP, NO FileShare"

    if [[ "$SHOW_DENIED" == "false" ]]; then
        sub_banner "Resources Engineer SHOULD reach"
        test_http "http://$TARGET_HOST/"       "Web Portal (HTTP 80)"   true
        test_http "http://$TARGET_HOST:8080/"  "Alt Web Portal (8080)"  true
        test_http "https://$TARGET_HOST/"      "Web Portal (HTTPS 443)" true
        test_tcp  "$LINUX_HOST" 22             "SSH to Ubuntu (22)"     true
    fi

    sub_banner "Resources Engineer should NOT reach (blocked)"
    test_tcp "$TARGET_HOST"  3389         "RDP (3389) – no rule for Engineering" false
    test_smb "//$TARGET_HOST/LabShare"    "SMB File Share – no rule"             false
    test_http "http://$TARGET_HOST:9090/" "Shadow IT App (9090)"                 false
    test_tcp "$TARGET_HOST"  1433         "SQL Server (1433)"                    false
    test_tcp "$TARGET_HOST"  5432         "PostgreSQL (5432)"                    false
    test_tcp "$TARGET_HOST"  6379         "Redis (6379)"                         false
}

run_contractor() {
    log INFO "Persona: Contractor (carol.white) | dept=Contractor | Policy: Allow-Contractors-WebOnly"
    log INFO "Expected: Web portal only – NO RDP, NO SSH, NO FileShare"

    if [[ "$SHOW_DENIED" == "false" ]]; then
        sub_banner "Resources Contractor SHOULD reach"
        test_http "http://$TARGET_HOST/"       "Web Portal (HTTP 80)"   true
        test_http "http://$TARGET_HOST:8080/"  "Alt Web Portal (8080)"  true
        test_http "https://$TARGET_HOST/"      "Web Portal (HTTPS 443)" true
    fi

    sub_banner "Resources Contractor should NOT reach (access denied)"
    test_tcp  "$TARGET_HOST" 3389         "RDP (3389)"                            false
    test_tcp  "$LINUX_HOST"  22           "SSH to Ubuntu (22)"                    false
    test_smb  "//$TARGET_HOST/LabShare"   "SMB File Share"                        false
    test_http "http://$TARGET_HOST:9090/" "Shadow IT App (9090)"                  false
    test_tcp  "$TARGET_HOST" 1433         "SQL Server (1433)"                     false
    test_tcp  "$TARGET_HOST" 5432         "PostgreSQL (5432)"                     false
    test_tcp  "$TARGET_HOST" 6379         "Redis (6379)"                          false
}

run_hr() {
    log INFO "Persona: HR Analyst (dave.hr) | dept=HR | Policy: (none – implicit deny)"
    log INFO "Expected: NO access to any private application"

    sub_banner "All resources should be BLOCKED for HR (implicit deny)"
    test_http "http://$TARGET_HOST/"       "Web Portal (HTTP 80)"   false
    test_http "http://$TARGET_HOST:8080/"  "Alt Web Portal (8080)"  false
    test_http "https://$TARGET_HOST/"      "Web Portal (HTTPS 443)" false
    test_tcp  "$TARGET_HOST" 3389          "RDP (3389)"             false
    test_tcp  "$LINUX_HOST"  22            "SSH to Ubuntu (22)"     false
    test_smb  "//$TARGET_HOST/LabShare"    "SMB File Share"         false
    test_http "http://$TARGET_HOST:9090/"  "Shadow IT App (9090)"   false
    test_tcp  "$TARGET_HOST" 1433          "SQL Server (1433)"      false
    test_tcp  "$TARGET_HOST" 5432          "PostgreSQL (5432)"      false
    test_tcp  "$TARGET_HOST" 6379          "Redis (6379)"           false
}

# ── Main ──────────────────────────────────────────────────────────────────────

check_deps

banner "ZPA Per-User Access Demo"
echo -e "  ${WHITE}Target Host : $TARGET_HOST${RESET}"
echo -e "  ${WHITE}Linux Host  : $LINUX_HOST${RESET}"
echo -e "  ${WHITE}Persona     : $PERSONA${RESET}"
echo -e "  ${WHITE}Log File    : $LOG_FILE${RESET}"
echo ""
echo -e "  ${GREEN}[PASS]    = allowed as expected${RESET}"
echo -e "  ${GREEN}[BLOCKED] = blocked as expected${RESET}"
echo -e "  ${RED}[FAIL]    = should be allowed but was blocked (check policy)${RESET}"
echo -e "  ${RED}[ALLOWED] = should be blocked but was allowed (check policy)${RESET}"

case "$PERSONA" in
    itadmin)    run_itadmin    ;;
    engineer)   run_engineer   ;;
    contractor) run_contractor ;;
    hr)         run_hr         ;;
    *)
        echo -e "${RED}Unknown persona: $PERSONA${RESET}"
        echo "Valid choices: itadmin | engineer | contractor | hr"
        exit 1
        ;;
esac

# ── Summary ───────────────────────────────────────────────────────────────────
banner "Access Demo Complete – persona: $PERSONA"
echo ""
echo -e "  ${WHITE}Tests matching policy  : ${GREEN}$PASS_COUNT${RESET}"
if [[ $FAIL_COUNT -gt 0 ]]; then
    echo -e "  ${WHITE}Tests NOT matching     : ${RED}$FAIL_COUNT${RESET}"
else
    echo -e "  ${WHITE}Tests NOT matching     : ${GREEN}$FAIL_COUNT${RESET}"
fi
echo ""
echo -e "  ${WHITE}Full log: $LOG_FILE${RESET}"
echo ""

if [[ $FAIL_COUNT -gt 0 ]]; then
    echo -e "  ${RED}ACTION REQUIRED: $FAIL_COUNT test(s) did not match expected policy.${RESET}"
    echo -e "  ${RED}Check ZPA Admin Portal → Policy → Policy Simulation to debug.${RESET}"
    echo ""
fi

echo -e "  ${CYAN}DEMO TIP: Run this script with different --persona values to show${RESET}"
echo -e "  ${CYAN}how ZPA enforces identity-aware access for each user type.${RESET}"
echo -e "  ${CYAN}Suggested pairs:${RESET}"
echo -e "  ${CYAN}  • itadmin vs contractor   (full access vs web-only)${RESET}"
echo -e "  ${CYAN}  • engineer vs hr          (partial vs zero access)${RESET}"
echo ""
