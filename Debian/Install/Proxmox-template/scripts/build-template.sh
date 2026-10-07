#!/usr/bin/env bash
set -Eeuo pipefail

# ==============================================================================
# Proxmox Debian 13 NGINX Reverse Proxy Template Builder
# Run this script ON A PROXMOX NODE as root.
# ==============================================================================

TEMPLATE_ID="${TEMPLATE_ID:-9001}"
HOSTNAME="${HOSTNAME:-debian13-nginx-template}"
STORAGE="${STORAGE:-local-zfs}"
BRIDGE="${BRIDGE:-vmbr0}"
CORES="${CORES:-2}"
MEMORY="${MEMORY:-1024}"
SWAP="${SWAP:-512}"
DISK_GB="${DISK_GB:-8}"
TEMPLATE_STORAGE="${TEMPLATE_STORAGE:-local}"
ROOT_PASSWORD="${ROOT_PASSWORD:-}"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
header(){ echo -e "\n${BLUE}$*${NC}\n$(printf '=%.0s' $(seq 1 ${#1}))"; }
info(){ echo -e "${BLUE}[INFO]${NC} $*"; }
ok(){ echo -e "${GREEN}[ OK ]${NC} $*"; }
warn(){ echo -e "${YELLOW}[WARN]${NC} $*"; }
die(){ echo -e "${RED}[FAIL]${NC} $*" >&2; exit 1; }

[[ $EUID -eq 0 ]] || die "Run as root on a Proxmox node."
command -v pct >/dev/null || die "pct not found. Run this on Proxmox VE."
command -v pveam >/dev/null || die "pveam not found."

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

header "Debian 13 Reverse Proxy Template Builder"

if pct status "$TEMPLATE_ID" >/dev/null 2>&1; then
  die "CT $TEMPLATE_ID already exists. Choose another TEMPLATE_ID."
fi

info "Refreshing Proxmox appliance catalog..."
pveam update

TEMPLATE="$(pveam available --section system | awk '$2 ~ /^debian-13-standard_.*_amd64\.tar\.(zst|gz)$/ {print $2}' | sort -V | tail -1)"
[[ -n "$TEMPLATE" ]] || die "No Debian 13 standard amd64 template found in pveam catalog."

info "Selected template: $TEMPLATE"

if ! pveam list "$TEMPLATE_STORAGE" | awk '{print $1}' | grep -Fq "$TEMPLATE"; then
  info "Downloading Debian template to $TEMPLATE_STORAGE..."
  pveam download "$TEMPLATE_STORAGE" "$TEMPLATE"
fi

TEMPLATE_PATH="${TEMPLATE_STORAGE}:vztmpl/${TEMPLATE}"

info "Creating unprivileged LXC CT $TEMPLATE_ID..."
CREATE_ARGS=(
  "$TEMPLATE_ID" "$TEMPLATE_PATH"
  --hostname "$HOSTNAME"
  --unprivileged 1
  --cores "$CORES"
  --memory "$MEMORY"
  --swap "$SWAP"
  --rootfs "${STORAGE}:${DISK_GB}"
  --net0 "name=eth0,bridge=${BRIDGE},ip=dhcp,type=veth,firewall=1"
  --onboot 0
  --features "nesting=1"
  --start 1
)
if [[ -n "$ROOT_PASSWORD" ]]; then
  CREATE_ARGS+=(--password "$ROOT_PASSWORD")
fi
pct create "${CREATE_ARGS[@]}"

info "Waiting for container boot..."
sleep 4

info "Copying repository into the build container..."
pct exec "$TEMPLATE_ID" -- mkdir -p /opt/proxmox-debian13-nginx
tar -C "$REPO_DIR" --exclude='.git' -cf - . | pct exec "$TEMPLATE_ID" -- tar -C /opt/proxmox-debian13-nginx -xf -

run_ct() {
  info "Running $1..."
  pct exec "$TEMPLATE_ID" -- bash "/opt/proxmox-debian13-nginx/scripts/$1" /opt/proxmox-debian13-nginx
}

run_ct 00-bootstrap.sh
run_ct 10-install-tools.sh
run_ct 20-install-nginx.sh
run_ct 30-install-certbot.sh
run_ct 40-install-fail2ban.sh
run_ct 50-install-nftables.sh
run_ct 80-install-proxy-check.sh

info "Validating NGINX..."
pct exec "$TEMPLATE_ID" -- nginx -t

info "Checking systemd health..."

SYSTEM_STATE="$(
    pct exec "$TEMPLATE_ID" -- \
        systemctl is-system-running 2>/dev/null ||
    true
)"

if [[ "$SYSTEM_STATE" == "running" ]]; then
    ok "systemd state: running"
else
    warn "systemd state: $SYSTEM_STATE"

    pct exec "$TEMPLATE_ID" -- \
        systemctl --failed \
        --no-pager || true

    die "Container systemd is not healthy."
fi

info "Running template cleanup..."
run_ct 90-cleanup-template.sh

info "Stopping container..."
pct stop "$TEMPLATE_ID"

info "Converting CT $TEMPLATE_ID to Proxmox template..."
pct template "$TEMPLATE_ID"

ok "Template $TEMPLATE_ID is ready."
echo
echo "Example:"
echo "  pct clone $TEMPLATE_ID 201 --hostname proxy01 --full 1"
echo "  pct set 201 --cores 2 --memory 1024 --swap 512"
echo "  pct start 201"