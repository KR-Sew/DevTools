#!/usr/bin/env bash
set -Eeuo pipefail
GREEN='\033[0;32m'; BLUE='\033[0;34m'; RED='\033[0;31m'; NC='\033[0m'
info(){ echo -e "${BLUE}[INFO]${NC} $*"; }
ok(){ echo -e "${GREEN}[ OK ]${NC} $*"; }
die(){ echo -e "${RED}[FAIL]${NC} $*" >&2; exit 1; }

[[ $EUID -eq 0 ]] || die "Run as root."
BASE_DIR="${1:-/opt/proxmox-debian13-nginx}"

info "Installing NGINX from Debian repository..."
apt-get install -y nginx

info "Installing managed NGINX configuration..."
install -m 0644 "$BASE_DIR/nginx/nginx.conf" /etc/nginx/nginx.conf
install -d -m 0755 /etc/nginx/snippets /etc/nginx/templates
cp -a "$BASE_DIR/nginx/snippets/." /etc/nginx/snippets/
cp -a "$BASE_DIR/nginx/templates/." /etc/nginx/templates/

rm -f /etc/nginx/sites-enabled/default

nginx -t
systemctl enable nginx
systemctl restart nginx

ok "NGINX installed and validated."
