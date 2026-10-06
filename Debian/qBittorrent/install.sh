#!/usr/bin/env bash
set -Eeuo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; BLUE='\033[0;34m'; NC='\033[0m'
info(){ echo -e "${BLUE}[INFO]${NC} $*"; }
ok(){ echo -e "${GREEN}[ OK ]${NC} $*"; }
warn(){ echo -e "${YELLOW}[WARN]${NC} $*"; }
fail(){ echo -e "${RED}[FAIL]${NC} $*" >&2; exit 1; }

cd "$(dirname "$0")"
[[ -f .env ]] || { cp .env.example .env; warn "Created .env from .env.example; review it before production use."; }
set -a; source .env; set +a

command -v docker >/dev/null || fail "Docker is not installed."
docker compose version >/dev/null 2>&1 || fail "Docker Compose plugin is not available."
[[ -d "$DOWNLOADS_PATH" ]] || fail "Downloads path does not exist: $DOWNLOADS_PATH"

info "Checking torrent storage mount..."
if findmnt -T "$DOWNLOADS_PATH" >/dev/null 2>&1; then
  findmnt -T "$DOWNLOADS_PATH" | tail -n +2
  ok "Storage is mounted."
else
  warn "$DOWNLOADS_PATH is not a separate mount. Verify NFS before downloading data."
fi

info "Creating persistent configuration directory..."
sudo mkdir -p "$CONFIG_PATH"
sudo chown "$PUID:$PGID" "$CONFIG_PATH"
ok "Configuration directory ready: $CONFIG_PATH"

if ss -lntH "sport = :$WEBUI_HOST_PORT" 2>/dev/null | grep -q .; then
  fail "TCP port $WEBUI_HOST_PORT is already in use."
fi

info "Pulling qBittorrent image..."
docker compose pull
info "Starting qBittorrent..."
docker compose up -d
ok "qBittorrent started."

echo
info "Container status:"
docker compose ps

echo
info "WebUI: http://127.0.0.1:${WEBUI_HOST_PORT}"
info "Public URL after NGINX setup: https://torrents.domain_name.com"
info "Initial username: admin"
sleep 2
PASSWORD_LINE=$(docker logs qbittorrent 2>&1 | grep -iE 'temporary password|administrator password' | tail -1 || true)
[[ -n "$PASSWORD_LINE" ]] && echo "$PASSWORD_LINE" || warn "Temporary password not found yet. Run: docker logs qbittorrent"
