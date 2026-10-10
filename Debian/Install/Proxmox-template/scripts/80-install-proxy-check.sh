#!/usr/bin/env bash
set -Eeuo pipefail
BASE_DIR="${1:-/opt/proxmox-debian13-nginx}"
install -m 0755 "$BASE_DIR/assets/proxy-check" /usr/local/sbin/proxy-check
echo "[ OK ] Installed /usr/local/sbin/proxy-check"
