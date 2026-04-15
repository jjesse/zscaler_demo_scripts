#!/usr/bin/env bash
# =============================================================================
# lab_config.sh – centralised lab configuration loader
#
# Source this file at the top of any demo script to pick up the user's
# personal lab settings from .env without hard-coding values.
#
#   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#   source "${SCRIPT_DIR}/../../lab_config.sh"   # adjust relative path
#
# Load order (last wins):
#   1. Built-in defaults (below)
#   2. <repo-root>/.env   – personal overrides (git-ignored)
#   3. Existing environment variables  – still honoured
#   4. CLI flags in each script        – highest priority
# =============================================================================

# ── Locate repo root (two levels up from scripts/*) ─────────────────────────
_lab_cfg_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_lab_repo_root="$(cd "${_lab_cfg_dir}/.." && pwd)"

# ── Source .env if present ───────────────────────────────────────────────────
if [[ -f "${_lab_repo_root}/.env" ]]; then
  # Only export simple KEY=VALUE lines; ignore comments and blanks.
  set -a
  # shellcheck disable=SC1091
  source "${_lab_repo_root}/.env"
  set +a
fi

# ── Defaults (used when neither .env nor an env-var supplies the value) ──────
WINDOWS_SERVER_IP="${WINDOWS_SERVER_IP:-192.168.1.20}"
LINUX_SERVER_IP="${LINUX_SERVER_IP:-192.168.1.10}"
LAB_SUBNET="${LAB_SUBNET:-192.168.1}"
LAB_SUBNET_CIDR="${LAB_SUBNET_CIDR:-192.168.1.0/24}"

export WINDOWS_SERVER_IP LINUX_SERVER_IP LAB_SUBNET LAB_SUBNET_CIDR
