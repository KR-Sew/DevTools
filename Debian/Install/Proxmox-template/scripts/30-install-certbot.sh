#!/usr/bin/env bash
set -Eeuo pipefail
GREEN='\033[0;32m'; BLUE='\033[0;34m'; RED='\033[0;31m'; NC='\033[0m'
info(){ echo -e "${BLUE}[INFO]${NC} $*"; }
ok(){ echo -e "${GREEN}[ OK ]${NC} $*"; }
die(){ echo -e "${RED}[FAIL]${NC} $*" >&2; exit 1; }

[[ $EUID -eq 0 ]] || die "Run as root."

info "Installing Certbot and NGINX plugin..."
apt-get install -y certbot python3-certbot-nginx

if systemctl list-unit-files certbot.timer >/dev/null 2>&1; then
  systemctl enable --now certbot.timer
fi

info "Running Certbot renewal dry-run only when certificates already exist..."
if find /etc/letsencrypt/renewal -maxdepth 1 -name '*.conf' -print -quit 2>/dev/null | grep -q .; then
  certbot renew --dry-run
else
  info "No certificates yet; dry-run skipped as expected for a template."
fi

ok "Certbot installed."
