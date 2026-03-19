#!/usr/bin/env bash
# =============================================================================
# setup_zia_client.sh – Install & configure ZIA Client Connector on Ubuntu
#
# Run as root:  sudo bash scripts/zia/linux/setup_zia_client.sh
# =============================================================================
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()    { echo -e "${CYAN}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

# ---------------------------------------------------------------------------
# Verify running as root
# ---------------------------------------------------------------------------
[[ $EUID -eq 0 ]] || error "This script must be run as root (sudo bash $0)"

info "=== ZIA Client Connector – Ubuntu Setup ==="

# ---------------------------------------------------------------------------
# Collect tenant information
# ---------------------------------------------------------------------------
echo ""
read -rp "Enter your ZIA tenant cloud name (e.g. zscalerthree.net): " ZIA_CLOUD
[[ -n "$ZIA_CLOUD" ]] || error "ZIA cloud name cannot be empty."

read -rp "Enter your ZIA username (email): " ZIA_USER
[[ -n "$ZIA_USER" ]] || error "ZIA username cannot be empty."

read -rsp "Enter your ZIA password: " ZIA_PASS
echo ""
[[ -n "$ZIA_PASS" ]] || error "ZIA password cannot be empty."

# ---------------------------------------------------------------------------
# Install dependencies
# ---------------------------------------------------------------------------
info "Installing dependencies..."
apt-get update -qq
apt-get install -y -qq curl wget apt-transport-https gnupg2 lsb-release ca-certificates

# ---------------------------------------------------------------------------
# Add Zscaler APT repository (placeholder – use actual repo in production)
# ---------------------------------------------------------------------------
info "Adding Zscaler repository..."
# NOTE: Replace with actual Zscaler repository URL from your tenant admin portal.
# The URL below is a placeholder pattern.
ZSCALER_REPO_URL="https://repos.zscaler.com/ubuntu"
ZIA_REPO_KEY_URL="https://repos.zscaler.com/ubuntu/gpg.key"

if ! curl -fsSL "${ZIA_REPO_KEY_URL}" | gpg --dearmor -o /usr/share/keyrings/zscaler.gpg 2>/dev/null; then
    warn "Could not fetch Zscaler GPG key (no internet or key URL changed)."
    warn "Continuing with system proxy configuration only."
    REPO_AVAILABLE=false
else
    echo "deb [signed-by=/usr/share/keyrings/zscaler.gpg arch=amd64] ${ZSCALER_REPO_URL} $(lsb_release -cs) main" \
        > /etc/apt/sources.list.d/zscaler.list
    REPO_AVAILABLE=true
fi

# ---------------------------------------------------------------------------
# Install ZIA Client Connector
# ---------------------------------------------------------------------------
if [[ "$REPO_AVAILABLE" == "true" ]]; then
    info "Installing ZIA Client Connector..."
    apt-get update -qq
    if apt-get install -y -qq zscaler 2>/dev/null; then
        success "ZIA Client Connector installed."
    else
        warn "Package 'zscaler' not found. The package name may differ in your tenant."
        warn "Download the .deb package from your ZIA Admin Portal → Client Connector Portal."
        REPO_AVAILABLE=false
    fi
fi

# ---------------------------------------------------------------------------
# Configure system-wide proxy settings
# ---------------------------------------------------------------------------
info "Configuring system proxy settings..."

ZIA_PROXY_HOST="gateway.${ZIA_CLOUD}"
ZIA_PROXY_PORT="80"

# /etc/environment for system-wide env vars
cat > /etc/environment <<EOF
http_proxy="http://${ZIA_PROXY_HOST}:${ZIA_PROXY_PORT}"
https_proxy="http://${ZIA_PROXY_HOST}:${ZIA_PROXY_PORT}"
HTTP_PROXY="http://${ZIA_PROXY_HOST}:${ZIA_PROXY_PORT}"
HTTPS_PROXY="http://${ZIA_PROXY_HOST}:${ZIA_PROXY_PORT}"
no_proxy="localhost,127.0.0.1,::1,169.254.0.0/16,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16"
NO_PROXY="localhost,127.0.0.1,::1,169.254.0.0/16,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16"
EOF

# /etc/profile.d/zia-proxy.sh for login shells
cat > /etc/profile.d/zia-proxy.sh <<'SHELL'
export http_proxy="http://gateway.ZIA_CLOUD_PLACEHOLDER:80"
export https_proxy="http://gateway.ZIA_CLOUD_PLACEHOLDER:80"
export HTTP_PROXY="http://gateway.ZIA_CLOUD_PLACEHOLDER:80"
export HTTPS_PROXY="http://gateway.ZIA_CLOUD_PLACEHOLDER:80"
export no_proxy="localhost,127.0.0.1,::1,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16"
export NO_PROXY="localhost,127.0.0.1,::1,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16"
SHELL
sed -i "s/ZIA_CLOUD_PLACEHOLDER/${ZIA_CLOUD}/g" /etc/profile.d/zia-proxy.sh

# APT proxy config
cat > /etc/apt/apt.conf.d/99zia-proxy <<EOF
Acquire::http::Proxy "http://${ZIA_PROXY_HOST}:${ZIA_PROXY_PORT}";
Acquire::https::Proxy "http://${ZIA_PROXY_HOST}:${ZIA_PROXY_PORT}";
EOF

success "System proxy configured → http://${ZIA_PROXY_HOST}:${ZIA_PROXY_PORT}"

# ---------------------------------------------------------------------------
# Verify connectivity through ZIA
# ---------------------------------------------------------------------------
info "Verifying connectivity through ZIA..."

export http_proxy="http://${ZIA_PROXY_HOST}:${ZIA_PROXY_PORT}"
export https_proxy="http://${ZIA_PROXY_HOST}:${ZIA_PROXY_PORT}"

if curl -fsSL --max-time 15 "https://ip.zscaler.com" | grep -qi "zscaler"; then
    success "Traffic confirmed routing through ZIA."
    echo ""
    curl -fsSL --max-time 15 "https://ip.zscaler.com" | grep -E "(Gateway|Gateway IP|ZEN)" || true
else
    warn "Could not verify ZIA connectivity. Check that ${ZIA_CLOUD} is reachable."
    warn "Ensure outbound 80/443 is not blocked by a local firewall."
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "========================================"
success "ZIA Setup Complete"
echo "========================================"
echo ""
info "System proxy: http://${ZIA_PROXY_HOST}:${ZIA_PROXY_PORT}"
info "Tenant cloud: ${ZIA_CLOUD}"
echo ""
info "Next steps:"
echo "  1. Log out and back in (or run 'source /etc/profile') to load proxy vars."
echo "  2. Verify: curl https://ip.zscaler.com"
echo "  3. Run: sudo bash scripts/zia/linux/generate_zia_traffic.sh"
echo ""
