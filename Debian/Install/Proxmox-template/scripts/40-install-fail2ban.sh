#!/usr/bin/env bash
set -Eeuo pipefail
GREEN='\033[0;32m'; BLUE='\033[0;34m'; RED='\033[0;31m'; NC='\033[0m'
info(){ echo -e "${BLUE}[INFO]${NC} $*"; }
ok(){ echo -e "${GREEN}[ OK ]${NC} $*"; }
die(){ echo -e "${RED}[FAIL]${NC} $*" >&2; exit 1; }

[[ $EUID -eq 0 ]] || die "Run as root."
BASE_DIR="${1:-/opt/proxmox-debian13-nginx}"

info "Installing Fail2ban..."
apt-get install -y fail2ban

install -m 0644 "$BASE_DIR/fail2ban/jail.local" /etc/fail2ban/jail.local
cp -a "$BASE_DIR/fail2ban/filter.d/." /etc/fail2ban/filter.d/

systemctl enable fail2ban
systemctl restart fail2ban

fail2ban-client ping
ok "Fail2ban installed."
