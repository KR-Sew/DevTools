#!/usr/bin/env bash
set -Eeuo pipefail
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; RED='\033[0;31m'; NC='\033[0m'
info(){ echo -e "${BLUE}[INFO]${NC} $*"; }
ok(){ echo -e "${GREEN}[ OK ]${NC} $*"; }
warn(){ echo -e "${YELLOW}[WARN]${NC} $*"; }
die(){ echo -e "${RED}[FAIL]${NC} $*" >&2; exit 1; }

[[ $EUID -eq 0 ]] || die "Run as root."
BASE_DIR="${1:-/opt/proxmox-debian13-nginx}"

info "Installing nftables..."
apt-get install -y nftables

install -m 0600 "$BASE_DIR/nftables/nftables.conf" /etc/nftables.conf.example
systemctl disable nftables >/dev/null 2>&1 || true
systemctl stop nftables >/dev/null 2>&1 || true

warn "nftables is intentionally NOT enabled in the template."
warn "Review /etc/nftables.conf.example on each clone before activation."
ok "nftables package and example policy installed."
