#!/usr/bin/env bash
set -Eeuo pipefail
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
info(){ echo -e "${BLUE}[INFO]${NC} $*"; }
ok(){ echo -e "${GREEN}[ OK ]${NC} $*"; }
warn(){ echo -e "${YELLOW}[WARN]${NC} $*"; }
die(){ echo -e "${RED}[FAIL]${NC} $*" >&2; exit 1; }

[[ $EUID -eq 0 ]] || die "Run as root."
BASE_DIR="${1:-/opt/proxmox-debian13-nginx}"

info "Installing first-boot identity service..."
install -m 0755 "$BASE_DIR/assets/proxy-firstboot" /usr/local/sbin/proxy-firstboot
install -m 0644 "$BASE_DIR/systemd/proxy-firstboot.service" /etc/systemd/system/proxy-firstboot.service
systemctl daemon-reload
systemctl enable proxy-firstboot.service

info "Cleaning package caches and transient state..."
apt-get clean
rm -rf /var/lib/apt/lists/*
rm -rf /tmp/* /var/tmp/*
rm -f /root/.bash_history
rm -rf /var/lib/fail2ban/*

info "Removing production certificate material if accidentally present..."
rm -rf /etc/letsencrypt/archive/* /etc/letsencrypt/live/* /etc/letsencrypt/renewal/* 2>/dev/null || true

info "Removing SSH host keys; first boot will regenerate them..."
rm -f /etc/ssh/ssh_host_*

info "Resetting machine identity..."
truncate -s 0 /etc/machine-id
rm -f /var/lib/dbus/machine-id
ln -sf /etc/machine-id /var/lib/dbus/machine-id

info "Vacuuming journal..."
journalctl --rotate >/dev/null 2>&1 || true
journalctl --vacuum-time=1s >/dev/null 2>&1 || true

ok "Container sanitized and ready to become a template."
