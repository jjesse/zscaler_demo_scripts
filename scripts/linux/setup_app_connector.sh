#!/usr/bin/env bash
# =============================================================================
# setup_app_connector.sh
# Installs and enrolls the Zscaler Private Access App Connector on Ubuntu 22.04.
#
# Usage (as root or with sudo):
#   sudo bash setup_app_connector.sh
#
# The script will prompt for the ZPA Provisioning Key if it has not been
# set as the environment variable ZPA_PROVISIONING_KEY.
# =============================================================================

set -euo pipefail

# ── Colour helpers ────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()    { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# ── Root check ────────────────────────────────────────────────────────────────
if [[ "${EUID}" -ne 0 ]]; then
  error "This script must be run as root (use sudo)."
  exit 1
fi

# ── OS check ─────────────────────────────────────────────────────────────────
if ! grep -qi 'ubuntu' /etc/os-release 2>/dev/null; then
  warn "This script is tested on Ubuntu 22.04. Proceeding anyway..."
fi

# ── Provisioning key ─────────────────────────────────────────────────────────
if [[ -z "${ZPA_PROVISIONING_KEY:-}" ]]; then
  read -rsp "Enter ZPA App Connector Provisioning Key: " ZPA_PROVISIONING_KEY
  echo
fi

if [[ -z "${ZPA_PROVISIONING_KEY}" ]]; then
  error "A provisioning key is required. Exiting."
  exit 1
fi

# ── Install dependencies ──────────────────────────────────────────────────────
info "Updating apt package lists..."
apt-get update -qq

info "Installing required packages (curl, gnupg, apt-transport-https)..."
apt-get install -y -qq curl gnupg apt-transport-https ca-certificates

# ── Add Zscaler APT repository ────────────────────────────────────────────────
KEYRING_PATH="/usr/share/keyrings/zscaler-archive-keyring.gpg"

if [[ ! -f "${KEYRING_PATH}" ]]; then
  info "Adding Zscaler GPG key..."
  curl -fsSL "https://yum.corpwebapps.net/gpg" \
    | gpg --dearmor -o "${KEYRING_PATH}"
fi

REPO_FILE="/etc/apt/sources.list.d/zscaler.list"
if [[ ! -f "${REPO_FILE}" ]]; then
  info "Adding Zscaler APT repository..."
  UBUNTU_CODENAME=$(lsb_release -cs 2>/dev/null || echo "focal")
  echo "deb [arch=amd64 signed-by=${KEYRING_PATH}] \
https://yum.corpwebapps.net/ubuntu ${UBUNTU_CODENAME} main" > "${REPO_FILE}"
  apt-get update -qq
fi

# ── Install App Connector ─────────────────────────────────────────────────────
info "Installing zpa-connector package..."
apt-get install -y -qq zpa-connector

# ── Configure the connector with the provisioning key ────────────────────────
info "Configuring App Connector with provisioning key..."
zpa-connector-configure --key "${ZPA_PROVISIONING_KEY}" --no-interactive

# ── Enable and start the service ─────────────────────────────────────────────
info "Enabling and starting zpa-connector service..."
systemctl enable --now zpa-connector

# ── Wait for the connector to register ───────────────────────────────────────
info "Waiting for connector to register with ZPA cloud (up to 60 s)..."
for i in $(seq 1 12); do
  sleep 5
  STATUS=$(systemctl is-active zpa-connector 2>/dev/null || true)
  if [[ "${STATUS}" == "active" ]]; then
    info "zpa-connector service is active."
    break
  fi
  echo -n "."
done
echo

# ── Print status ──────────────────────────────────────────────────────────────
systemctl status zpa-connector --no-pager || true

info "--------------------------------------------------------------"
info "Installation complete."
info "Log in to the ZPA Admin Portal → Administration → App Connectors"
info "to confirm this connector shows as Connected."
info "--------------------------------------------------------------"
info "Useful commands:"
info "  sudo systemctl status zpa-connector    # service status"
info "  sudo journalctl -u zpa-connector -f    # live logs"
info "  sudo tail -f /var/log/zpa-connector/connector.log"
