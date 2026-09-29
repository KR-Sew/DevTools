#!/usr/bin/env bash
set -Eeuo pipefail
GREEN='\033[0;32m'; BLUE='\033[0;34m'; NC='\033[0m'
info(){ echo -e "${BLUE}[INFO]${NC} $*"; }; ok(){ echo -e "${GREEN}[ OK ]${NC} $*"; }
cd "$(dirname "$0")"
info "Pulling latest qBittorrent image..."
docker compose pull
info "Recreating container if required..."
docker compose up -d
ok "Update completed."
docker compose ps
