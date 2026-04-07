#!/usr/bin/env bash
# simulate_attacker.sh – Zscaler Deception Attacker Simulation (Linux)
#
# Simulates an attacker who has already gained a foothold on an internal
# machine and is performing post-breach reconnaissance, credential discovery,
# and lateral movement.  Each phase triggers Zscaler Deception alerts on the
# decoy services started by setup_decoy_services.sh.
#
# ⚠  WARNING: Run only in authorised lab environments.
#    Never execute against production networks or systems you do not own.
#
# Attack phases:
#   Phase 1 – Internal Reconnaissance     (ARP, ping sweep, DNS)
#   Phase 2 – Service Discovery           (TCP port scan, banner grab)
#   Phase 3 – Credential / Token Search   (locate breadcrumb files)
#   Phase 4 – Decoy Interaction           (use fake creds → trigger alerts)
#   Phase 5 – Post-Exploitation Probes    (DB, cloud token, exfil simulation)
#
# Prerequisites:
#   curl, nc (netcat), arp, ping   (all standard on Ubuntu 22.04)
#
# Usage:
#   sudo bash simulate_attacker.sh [OPTIONS]
#
# Options:
#   --subnet CIDR          Target subnet  (default: 192.168.1.0/24)
#   --target HOST          Primary target IP (default: 192.168.1.10)
#   --attacker-ip IP       Attacker's own IP for display (default: auto)
#   --local                Simulate from local machine (no separate attacker host)
#   --phase N              Run only a specific phase (1–5)
#   --no-pause             Skip "press Enter" pauses between phases
#   --speed SECS           Pause between individual steps (default: 1)
#
# Examples:
#   sudo bash simulate_attacker.sh --local
#   sudo bash simulate_attacker.sh --target 192.168.1.10 --no-pause
#   sudo bash simulate_attacker.sh --phase 4

set -euo pipefail

# ── Defaults ───────────────────────────────────────────────────────────────────
SUBNET="192.168.1.0/24"
TARGET_HOST="192.168.1.10"
ATTACKER_IP=""
LOCAL_MODE=false
ONLY_PHASE=""
NO_PAUSE=false
STEP_SPEED=1
LOG_FILE="/tmp/deception_attacker_sim.log"

PORT_WEB=8081
PORT_SSH=2222
PORT_DB=3307
PORT_FILE=4445

# ── Colours ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; MAGENTA='\033[0;35m'; WHITE='\033[1;37m'
BOLD='\033[1m'; DIM='\033[2m'; RESET='\033[0m'

# ── Arg parsing ────────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        --subnet)      SUBNET="$2";       shift 2 ;;
        --target)      TARGET_HOST="$2";  shift 2 ;;
        --attacker-ip) ATTACKER_IP="$2";  shift 2 ;;
        --local)       LOCAL_MODE=true;   shift ;;
        --phase)       ONLY_PHASE="$2";   shift 2 ;;
        --no-pause)    NO_PAUSE=true;     shift ;;
        --speed)       STEP_SPEED="$2";   shift 2 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

# Auto-detect attacker IP if not provided
if [[ -z "${ATTACKER_IP}" ]]; then
    ATTACKER_IP=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "127.0.0.1")
fi

# ── Logging ────────────────────────────────────────────────────────────────────
log() {
    local level="$1"; shift
    local msg="$*"
    local ts
    ts=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${ts}] [${level}] ${msg}" >> "${LOG_FILE}"
    case "${level}" in
        ALERT)  echo -e "  ${RED}${BOLD}[DECEPTION ALERT EXPECTED]${RESET} ${RED}${msg}${RESET}" ;;
        ACTION) echo -e "  ${YELLOW}[ATTACKER ACTION]${RESET}  ${msg}" ;;
        FOUND)  echo -e "  ${GREEN}[FOUND]${RESET}           ${msg}" ;;
        INFO)   echo -e "  ${CYAN}[INFO]${RESET}            ${msg}" ;;
        RESULT) echo -e "  ${WHITE}${msg}${RESET}" ;;
        DIM)    echo -e "  ${DIM}${msg}${RESET}" ;;
    esac
}

banner() {
    local title="$1"
    local width=68
    echo ""
    echo -e "${MAGENTA}$(printf '═%.0s' $(seq 1 ${width}))${RESET}"
    echo -e "${MAGENTA}  ${BOLD}${title}${RESET}"
    echo -e "${MAGENTA}$(printf '═%.0s' $(seq 1 ${width}))${RESET}"
    echo ""
}

phase_header() {
    local num="$1"
    local title="$2"
    echo ""
    echo -e "${CYAN}$(printf '─%.0s' $(seq 1 68))${RESET}"
    echo -e "${CYAN}  ${BOLD}Phase ${num}: ${title}${RESET}"
    echo -e "${CYAN}$(printf '─%.0s' $(seq 1 68))${RESET}"
    echo ""
}

pause_for_narration() {
    if [[ "${NO_PAUSE}" == "false" ]]; then
        echo ""
        echo -e "  ${DIM}↵  Press Enter to continue to next phase…${RESET}"
        read -r
    fi
    sleep "${STEP_SPEED}"
}

step_delay() {
    sleep "${STEP_SPEED}"
}

# ── Dependency check ───────────────────────────────────────────────────────────
check_deps() {
    local missing=()
    command -v curl  >/dev/null 2>&1 || missing+=(curl)
    command -v nc    >/dev/null 2>&1 || missing+=(netcat-openbsd)
    if [[ ${#missing[@]} -gt 0 ]]; then
        log INFO "Missing tools: ${missing[*]}. Attempting install…"
        if apt-get install -y -qq "${missing[@]}" 2>/dev/null; then
            log INFO "Dependencies installed."
        else
            log INFO "Could not install ${missing[*]} automatically. Some steps may fail."
        fi
    fi
}

# ── Phase 1: Internal Reconnaissance ──────────────────────────────────────────
phase_recon() {
    phase_header 1 "Internal Reconnaissance"

    log ACTION "Attacker IP: ${ATTACKER_IP}"
    log ACTION "Dumping ARP cache to identify adjacent hosts…"
    step_delay

    # Show ARP table
    local arp_output
    arp_output=$(arp -a 2>/dev/null | head -20 || ip neigh 2>/dev/null | head -20 || echo "(arp not available)")
    echo "${arp_output}" | while IFS= read -r line; do
        log RESULT "    ${line}"
    done
    echo ""
    step_delay

    log ACTION "Performing ICMP ping sweep on ${SUBNET}…"
    local subnet_base
    subnet_base=$(echo "${SUBNET}" | cut -d'/' -f1 | cut -d'.' -f1-3)
    local live_hosts=()

    for i in 1 10 20 30 40 100 101 200; do
        local host="${subnet_base}.${i}"
        if ping -c 1 -W 1 "${host}" >/dev/null 2>&1; then
            log FOUND "${host} — host is ALIVE"
            live_hosts+=("${host}")
        else
            log DIM    "${host} — no response"
        fi
    done
    step_delay

    log ACTION "Performing reverse DNS lookups on live hosts…"
    for host in "${live_hosts[@]}"; do
        local hostname
        hostname=$(nslookup "${host}" 2>/dev/null | awk '/name = / {print $NF}' | sed 's/\.$//' || echo "(no PTR)")
        log RESULT "    ${host}  →  ${hostname:-no PTR record}"
    done

    log INFO "Phase 1 complete. Identified live hosts on ${SUBNET}."
    echo ""
    log INFO "DEMO: Deception portal should show no alerts yet — recon is passive."
}

# ── Phase 2: Service Discovery ─────────────────────────────────────────────────
phase_service_discovery() {
    phase_header 2 "Service Discovery (Port Scanning + Banner Grabbing)"

    local target="${TARGET_HOST}"
    log ACTION "Scanning ${target} for open ports…"
    step_delay

    # Common port list covering real services and decoy ports
    local ports=(22 80 443 445 2222 3306 3307 4445 8080 8081 3389 5432 6379)
    local open_ports=()

    for port in "${ports[@]}"; do
        if nc -z -w 2 "${target}" "${port}" 2>/dev/null; then
            log FOUND "${target}:${port}  — OPEN"
            open_ports+=("${port}")
        else
            log DIM    "${target}:${port}  — closed/filtered"
        fi
        sleep 0.3
    done
    echo ""
    step_delay

    log ACTION "Grabbing service banners on open ports…"
    for port in "${open_ports[@]}"; do
        local banner
        banner=$(echo "" | nc -w 2 "${target}" "${port}" 2>/dev/null | head -1 | tr -d '\r\n' || echo "")
        if [[ -n "${banner}" ]]; then
            log FOUND "Banner on ${target}:${port}:  ${banner:0:100}"
        fi
        sleep 0.3
    done
    echo ""

    log ACTION "Grabbing HTTP titles on web ports…"
    for port in 80 8080 8081; do
        local title
        title=$(curl -sk --connect-timeout 3 --max-time 5 "http://${target}:${port}" 2>/dev/null \
                | grep -i '<title>' | sed 's/.*<title>\(.*\)<\/title>.*/\1/' | head -1 || echo "")
        if [[ -n "${title}" ]]; then
            log FOUND "HTTP title on ${target}:${port}:  ${title}"
        fi
    done

    log INFO "Phase 2 complete."
    echo ""
    log INFO "DEMO: Port 2222 (SSH decoy), 3307 (MySQL decoy), 4445 (file service decoy),"
    log INFO "      and 8081 (web portal decoy) are visible alongside real services."
    log INFO "      An attacker cannot tell which are real — they must probe all of them."
}

# ── Phase 3: Credential / Token Discovery ─────────────────────────────────────
phase_credential_discovery() {
    phase_header 3 "Credential & Token Discovery (Deception Lure Access)"

    log ACTION "Searching common credential storage locations on this machine…"
    step_delay

    # Breadcrumb files planted by setup_decoy_services.sh
    local decoy_dir="/tmp/deception_demo"

    local locations=(
        "${decoy_dir}/.aws/credentials:AWS credentials"
        "${decoy_dir}/.ssh/config:SSH client config"
        "${decoy_dir}/app/.env:Application environment file"
        "${decoy_dir}/backup/db_backup.sql:Database backup file"
        "${HOME}/.aws/credentials:Real AWS credentials (if any)"
        "${HOME}/.ssh/config:Real SSH config (if any)"
        "/etc/passwd:System user list"
        "/etc/hosts:Hosts file (for internal hostnames)"
    )

    for entry in "${locations[@]}"; do
        local path="${entry%%:*}"
        local label="${entry##*:}"
        if [[ -f "${path}" ]]; then
            log FOUND "${label}  →  ${path}"
            # Read and show interesting lines without dumping everything
            local interesting
            interesting=$(grep -iE "(password|passwd|key|secret|token|host|user|access)" \
                          "${path}" 2>/dev/null | grep -v '^#' | head -5 || echo "")
            if [[ -n "${interesting}" ]]; then
                echo "${interesting}" | while IFS= read -r line; do
                    log RESULT "    ${line}"
                done
            fi
        else
            log DIM    "${label}  —  not found at ${path}"
        fi
        step_delay
    done

    echo ""
    log ALERT "Deception token READ — Fake AWS credentials accessed at ${decoy_dir}/.aws/credentials"
    log ALERT "Deception token READ — Fake SSH config accessed at ${decoy_dir}/.ssh/config"
    log ALERT "Deception token READ — Fake .env file accessed at ${decoy_dir}/app/.env"
    echo ""
    log INFO "DEMO: Three lures were read. The Deception portal should now show"
    log INFO "      HIGH-severity alerts for credential token access on this endpoint."
}

# ── Phase 4: Decoy Interaction (Triggers Critical Alerts) ─────────────────────
phase_decoy_interaction() {
    phase_header 4 "Decoy Interaction — Using Fake Credentials"

    log ACTION "Using SSH credentials found in fake config to connect to decoy SSH server…"
    log INFO   "Target: ${TARGET_HOST}:${PORT_SSH}  (fake credentials: lab-admin / P@ssw0rd!fake)"
    step_delay

    # SSH honeypot connection — sends the SSH version string, receives banner
    local ssh_banner
    ssh_banner=$(echo "SSH-2.0-OpenSSH_8.9p1 AttackerClient" | \
                 nc -w 5 "${TARGET_HOST}" "${PORT_SSH}" 2>/dev/null | \
                 head -2 | tr -d '\r' || echo "(no response)")
    if [[ -n "${ssh_banner}" ]]; then
        log FOUND "SSH honeypot responded:"
        echo "${ssh_banner}" | while IFS= read -r line; do
            log RESULT "    ${line}"
        done
        log ALERT "CRITICAL — Decoy SSH server touched: ${TARGET_HOST}:${PORT_SSH}"
        log ALERT "           Attacker IP: ${ATTACKER_IP}"
        log ALERT "           Credential attempted: lab-admin"
    else
        log INFO  "SSH decoy not responding — ensure setup_decoy_services.sh is running."
    fi
    echo ""
    step_delay

    log ACTION "Attempting login to fake internal web portal with discovered credentials…"
    log INFO   "Target: http://${TARGET_HOST}:${PORT_WEB}/login  (admin / Welcome1!fake)"
    step_delay

    local web_code
    web_code=$(curl -sk -o /dev/null -w "%{http_code}" \
               --connect-timeout 5 --max-time 8 \
               -X POST "http://${TARGET_HOST}:${PORT_WEB}/login" \
               -d "username=admin&password=Welcome1%21fake" 2>/dev/null || echo "000")
    if [[ "${web_code}" != "000" ]]; then
        log FOUND "Web portal responded: HTTP ${web_code}"
        log ALERT "CRITICAL — Decoy web portal login attempt: http://${TARGET_HOST}:${PORT_WEB}/login"
        log ALERT "           Attacker IP: ${ATTACKER_IP}"
        log ALERT "           Credentials submitted: admin / Welcome1!fake"
    else
        log INFO  "Web portal decoy not responding — ensure setup_decoy_services.sh is running."
    fi
    echo ""
    step_delay

    log ACTION "Probing fake MySQL server on ${TARGET_HOST}:${PORT_DB} with app credentials…"
    log INFO   "Using: app_prod_user / Pr0dDB\$ecret!2024 (from .env breadcrumb)"
    step_delay

    local db_banner
    db_banner=$(echo "" | nc -w 5 "${TARGET_HOST}" "${PORT_DB}" 2>/dev/null | \
                strings | head -3 | tr -d '\r' || echo "")
    if [[ -n "${db_banner}" ]]; then
        log FOUND "Database server responded:"
        echo "${db_banner}" | while IFS= read -r line; do
            log RESULT "    ${line}"
        done
        log ALERT "CRITICAL — Decoy database server probed: ${TARGET_HOST}:${PORT_DB}"
        log ALERT "           Attacker IP: ${ATTACKER_IP}"
        log ALERT "           Credential attempted: app_prod_user"
    else
        log INFO  "Database decoy not responding — ensure setup_decoy_services.sh is running."
    fi
    echo ""
    step_delay

    log ACTION "Connecting to fake file service on ${TARGET_HOST}:${PORT_FILE}…"
    step_delay

    local file_banner
    file_banner=$(echo "LIST" | nc -w 5 "${TARGET_HOST}" "${PORT_FILE}" 2>/dev/null | \
                  head -2 | tr -d '\r' || echo "")
    if [[ -n "${file_banner}" ]]; then
        log FOUND "File service responded:"
        echo "${file_banner}" | while IFS= read -r line; do
            log RESULT "    ${line}"
        done
        log ALERT "CRITICAL — Decoy file service touched: ${TARGET_HOST}:${PORT_FILE}"
        log ALERT "           Attacker IP: ${ATTACKER_IP}"
    else
        log INFO  "File service decoy not responding — ensure setup_decoy_services.sh is running."
    fi
    echo ""

    log INFO "Phase 4 complete."
    log INFO "DEMO: Check the Deception portal — multiple CRITICAL alerts should have fired."
    log INFO "      Each alert includes: attacker IP, decoy touched, credential used."
}

# ── Phase 5: Post-Exploitation Probes ─────────────────────────────────────────
phase_post_exploitation() {
    phase_header 5 "Post-Exploitation: Cloud Token Abuse + Exfil Probe"

    log ACTION "Testing fake AWS access key discovered in credentials file…"
    log INFO   "Key: DEMO-FAKE-KEY-ID-LAB1-REPLACE  (this will be caught by Deception)"
    step_delay

    # Attempt an AWS STS call with the fake credentials
    # In a real Deception deployment the fake key triggers a canary token alert
    local aws_response
    aws_response=$(curl -sk --connect-timeout 5 --max-time 8 \
        "https://sts.amazonaws.com/?Action=GetCallerIdentity&Version=2011-06-15" \
        -H "Authorization: AWS4-HMAC-SHA256 Credential=DEMO-FAKE-KEY-ID-LAB1-REPLACE/20241101/us-east-1/sts/aws4_request, SignedHeaders=host;x-amz-date, Signature=fakesignature" \
        -H "X-Amz-Date: 20241101T000000Z" 2>/dev/null | head -3 || echo "(no response)")
    if [[ -n "${aws_response}" ]]; then
        log FOUND "AWS STS response received (credential is a canary token — alert will fire):"
        log RESULT "    ${aws_response:0:120}"
    else
        log INFO  "No response from AWS STS (expected in sandboxed labs)."
    fi
    log ALERT "Deception Canary Token USED — Fake AWS key DEMO-FAKE-KEY-ID-LAB1-REPLACE"
    log ALERT "Cloud API call from: ${ATTACKER_IP}"
    echo ""
    step_delay

    log ACTION "Simulating data staging (creating archive of interesting files)…"
    local stage_dir="/tmp/attacker_stage_$$"
    mkdir -p "${stage_dir}"
    # Copy only the fake decoy files — never real system files
    cp "/tmp/deception_demo/.aws/credentials"     "${stage_dir}/creds.txt"     2>/dev/null || true
    cp "/tmp/deception_demo/backup/db_backup.sql" "${stage_dir}/backup.sql"    2>/dev/null || true
    cp "/tmp/deception_demo/app/.env"             "${stage_dir}/app_config.txt" 2>/dev/null || true
    local staged_count
    staged_count=$(ls "${stage_dir}" 2>/dev/null | wc -l)
    log FOUND "Staged ${staged_count} file(s) in ${stage_dir}"
    log RESULT "    Files: $(ls "${stage_dir}" 2>/dev/null | tr '\n' ' ')"
    echo ""
    step_delay

    log ACTION "Probing database ports for additional backend services…"
    local extra_ports=(5432 1433 27017 6379)
    for port in "${extra_ports[@]}"; do
        if nc -z -w 2 "${TARGET_HOST}" "${port}" 2>/dev/null; then
            log FOUND "${TARGET_HOST}:${port} — OPEN (additional service)"
        else
            log DIM    "${TARGET_HOST}:${port} — closed"
        fi
        sleep 0.3
    done
    echo ""

    # Clean up staging directory
    rm -rf "${stage_dir}" 2>/dev/null || true

    log INFO "Phase 5 complete."
    log INFO "DEMO: The Deception portal's attack timeline now shows the full kill chain:"
    log INFO "      Credential lure access → Decoy interactions → Cloud token abuse"
}

# ── Main ───────────────────────────────────────────────────────────────────────

check_deps

banner "Zscaler Deception – Attacker Simulation"
echo -e "  ${WHITE}Attacker IP   :${RESET} ${ATTACKER_IP}"
echo -e "  ${WHITE}Target Host   :${RESET} ${TARGET_HOST}"
echo -e "  ${WHITE}Subnet        :${RESET} ${SUBNET}"
echo -e "  ${WHITE}Local Mode    :${RESET} ${LOCAL_MODE}"
echo -e "  ${WHITE}Log File      :${RESET} ${LOG_FILE}"
echo ""
echo -e "  ${RED}${BOLD}WARNING:${RESET} This script simulates attacker behaviour."
echo -e "  ${RED}         Run only in authorised lab environments.${RESET}"
echo ""
echo -e "  ${CYAN}Colour key:${RESET}"
echo -e "  ${RED}${BOLD}[DECEPTION ALERT EXPECTED]${RESET}  = this action should trigger a Deception alert"
echo -e "  ${YELLOW}[ATTACKER ACTION]${RESET}            = what the attacker is doing"
echo -e "  ${GREEN}[FOUND]${RESET}                      = attacker discovered something"
echo ""

if [[ "${NO_PAUSE}" == "false" ]]; then
    echo -e "  ${DIM}↵  Press Enter to begin the attacker simulation…${RESET}"
    read -r
fi

# Run phases (all or a specific one)
run_phase() {
    local phase_num="$1"
    if [[ -z "${ONLY_PHASE}" || "${ONLY_PHASE}" == "${phase_num}" ]]; then
        case "${phase_num}" in
            1) phase_recon             ;;
            2) phase_service_discovery ;;
            3) phase_credential_discovery ;;
            4) phase_decoy_interaction ;;
            5) phase_post_exploitation ;;
        esac
        if [[ -z "${ONLY_PHASE}" && "${phase_num}" -lt 5 ]]; then
            pause_for_narration
        fi
    fi
}

run_phase 1
run_phase 2
run_phase 3
run_phase 4
run_phase 5

# ── Final Summary ──────────────────────────────────────────────────────────────
banner "Attacker Simulation Complete"
echo -e "  ${WHITE}The simulated attack triggered the following Deception events:${RESET}"
echo ""
echo -e "  ${RED}●${RESET} Deception lures accessed  — credential files read on endpoint"
echo -e "  ${RED}●${RESET} SSH honeypot interaction   — ${TARGET_HOST}:${PORT_SSH}"
echo -e "  ${RED}●${RESET} Web portal login attempt   — ${TARGET_HOST}:${PORT_WEB}"
echo -e "  ${RED}●${RESET} Database probe             — ${TARGET_HOST}:${PORT_DB}"
echo -e "  ${RED}●${RESET} File service probe         — ${TARGET_HOST}:${PORT_FILE}"
echo -e "  ${RED}●${RESET} Cloud canary token used    — Fake AWS key in API call"
echo ""
echo -e "  ${CYAN}Next steps (in the Deception portal):${RESET}"
echo -e "  1. Navigate to Alerts → Active Alerts"
echo -e "     Show all 6 alerts — every one is CRITICAL or HIGH"
echo -e "  2. Navigate to Investigation → Attack Timeline"
echo -e "     Show the full kill chain reconstructed automatically"
echo -e "  3. Navigate to Investigation → Attack Graph"
echo -e "     Show lateral movement visualisation"
echo -e "  4. Click Respond → Isolate Endpoint on the SSH alert"
echo -e "     Show SOAR playbook execution (ZPA block + ZIA quarantine)"
echo ""
echo -e "  ${WHITE}Full simulation log:${RESET} ${LOG_FILE}"
echo ""
