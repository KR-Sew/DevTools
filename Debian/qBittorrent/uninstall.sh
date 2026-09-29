#!/usr/bin/env bash
set -Eeuo pipefail
YELLOW='\033[1;33m'; GREEN='\033[0;32m'; NC='\033[0m'
cd "$(dirname "$0")"
echo -e "${YELLOW}[WARN]${NC} This removes the qBittorrent container only."
echo "Persistent config and /mnt/torrents are intentionally preserved."
docker compose down
printf '%b\n' "${GREEN}[ OK ]${NC} Container removed; persistent data preserved."
