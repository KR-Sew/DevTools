#!/usr/bin/env bash

set -Eeuo pipefail

# ==============================================================================
# Debian 13 NGINX Reverse Proxy - Proxmox Node Deployment
#
# Creates a reverse-proxy LXC from the prepared Proxmox template.
#
# It does NOT configure:
#   - public domains
#   - backend/upstream servers
#   - Let's Encrypt certificates
#
# Those are handled separately by add-proxy-host.sh.
# ==============================================================================

TEMPLATE_ID="9001"

VMID=""
CT_HOSTNAME=""
IP_ADDRESS=""
GATEWAY=""
BRIDGE="vmbr0"

CORES="2"
MEMORY="1024"
SWAP="512"

START_TIMEOUT="60"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

info() { echo -e "${BLUE}[INFO]${NC} $*"; }
ok()   { echo -e "${GREEN}[ OK ]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
fail() { echo -e "${RED}[FAIL]${NC} $*" >&2; }

die() {
    fail "$*"
    exit 1
}

section() {
    echo
    echo -e "${CYAN}$*${NC}"
    printf '%*s\n' "${#1}" '' | tr ' ' '-'
}

usage() {
    cat <<EOF

Debian 13 Reverse Proxy Node Deployment

Usage:

  sudo $0 \\
      --vmid ID \\
      --hostname NAME \\
      --ip ADDRESS/CIDR \\
      --gateway ADDRESS \\
      [--bridge BRIDGE]

Required:

  --vmid ID             New Proxmox CT ID
  --hostname NAME       Container hostname
  --ip ADDRESS/CIDR     Static IPv4 address
  --gateway ADDRESS     IPv4 gateway

Optional:

  --template ID         Template ID     [default: 9001]
  --bridge NAME         Proxmox bridge  [default: vmbr0]
  --cores NUMBER        CPU cores       [default: 2]
  --memory MB           RAM              [default: 1024]
  --swap MB             Swap             [default: 512]

  -h, --help            Show this help

Example:

  sudo $0 \\
      --vmid 201 \\
      --hostname proxy01 \\
      --ip 10.10.204.20/24 \\
      --gateway 10.10.204.254 \\
      --bridge vmbr0

EOF
}

on_error() {
    local exit_code=$?
    local line_no="${BASH_LINENO[0]:-unknown}"

    echo
    fail "Deployment failed at line ${line_no} (exit ${exit_code})."

    if [[ -n "${VMID:-}" ]] && pct status "$VMID" &>/dev/null; then
        warn "CT ${VMID} was left intact for troubleshooting."
        warn "Use: pct enter ${VMID}"
    fi

    exit "$exit_code"
}

trap on_error ERR

ct_exec() {
    pct exec "$VMID" -- "$@"
}

validate_ipv4_cidr() {
    [[ "$1" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}/[0-9]{1,2}$ ]]
}

validate_ipv4() {
    [[ "$1" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --template)
            TEMPLATE_ID="$2"
            shift 2
            ;;
        --vmid)
            VMID="$2"
            shift 2
            ;;
        --hostname)
            CT_HOSTNAME="$2"
            shift 2
            ;;
        --ip)
            IP_ADDRESS="$2"
            shift 2
            ;;
        --gateway)
            GATEWAY="$2"
            shift 2
            ;;
        --bridge)
            BRIDGE="$2"
            shift 2
            ;;
        --cores)
            CORES="$2"
            shift 2
            ;;
        --memory)
            MEMORY="$2"
            shift 2
            ;;
        --swap)
            SWAP="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            die "Unknown parameter: $1"
            ;;
    esac
done

echo
echo "Debian 13 Reverse Proxy Node Deployment"
echo "======================================="

[[ $EUID -eq 0 ]] ||
    die "This script must be run as root."

command -v pct >/dev/null ||
    die "pct was not found. Run this script on a Proxmox node."

section "Validation"

[[ -n "$VMID" ]]        || die "--vmid is required."
[[ -n "$CT_HOSTNAME" ]] || die "--hostname is required."
[[ -n "$IP_ADDRESS" ]]  || die "--ip is required."
[[ -n "$GATEWAY" ]]     || die "--gateway is required."

validate_ipv4_cidr "$IP_ADDRESS" ||
    die "Invalid IPv4/CIDR: $IP_ADDRESS"

validate_ipv4 "$GATEWAY" ||
    die "Invalid gateway: $GATEWAY"

if pct config "$VMID" &>/dev/null; then
    die "CT ${VMID} already exists."
fi

pct config "$TEMPLATE_ID" &>/dev/null ||
    die "Template ${TEMPLATE_ID} does not exist."

pct config "$TEMPLATE_ID" |
    grep -q '^template: 1$' ||
    die "CT ${TEMPLATE_ID} is not a Proxmox template."

ok "Template: ${TEMPLATE_ID}"
ok "New CT: ${VMID}"
ok "Hostname: ${CT_HOSTNAME}"

section "Container"

info "Cloning template ${TEMPLATE_ID}..."

pct clone \
    "$TEMPLATE_ID" \
    "$VMID" \
    --hostname "$CT_HOSTNAME" \
    --full 1

ok "CT ${VMID} cloned."

info "Configuring resources..."

pct set "$VMID" \
    --cores "$CORES" \
    --memory "$MEMORY" \
    --swap "$SWAP"

ok "CPU: ${CORES} core(s)"
ok "Memory: ${MEMORY} MB"
ok "Swap: ${SWAP} MB"

section "Network"

pct set "$VMID" \
    --net0 \
    "name=eth0,bridge=${BRIDGE},ip=${IP_ADDRESS},gw=${GATEWAY},type=veth"

ok "Address: ${IP_ADDRESS}"
ok "Gateway: ${GATEWAY}"
ok "Bridge: ${BRIDGE}"

section "Boot"

info "Starting CT ${VMID}..."

pct start "$VMID"

info "Waiting for systemd..."

SYSTEM_STATE=""

for ((i=1; i<=START_TIMEOUT; i++)); do
    SYSTEM_STATE="$(
        ct_exec systemctl is-system-running 2>/dev/null ||
        true
    )"

    [[ "$SYSTEM_STATE" == "running" ]] && break

    sleep 1
done

if [[ "$SYSTEM_STATE" != "running" ]]; then
    warn "systemd state: ${SYSTEM_STATE:-unknown}"
    ct_exec systemctl --failed --no-pager || true
    die "Container did not reach a healthy systemd state."
fi

ok "systemd state: running"

section "Identity"

if ct_exec test -f /var/lib/proxy-template/initialized; then
    ok "Unique machine identity initialized."
else
    die "First-boot identity initialization did not complete."
fi

section "Connectivity"

if ct_exec getent hosts deb.debian.org >/dev/null 2>&1; then
    ok "DNS resolution: working"
else
    die "DNS resolution failed."
fi

if ct_exec curl \
    --silent \
    --show-error \
    --connect-timeout 5 \
    --output /dev/null \
    https://deb.debian.org/
then
    ok "Internet connectivity: working"
else
    warn "Internet connectivity check failed."
fi

section "Services"

ct_exec nginx -t

ct_exec systemctl is-active --quiet nginx ||
    die "NGINX is not running."

ct_exec systemctl is-active --quiet fail2ban ||
    die "Fail2ban is not running."

ok "NGINX: active"
ok "Fail2ban: active"

section "Health"

ct_exec /usr/local/sbin/proxy-check

section "Deployment complete"

echo
echo "  CT ID     : ${VMID}"
echo "  Hostname  : ${CT_HOSTNAME}"
echo "  Address   : ${IP_ADDRESS}"
echo "  Gateway   : ${GATEWAY}"
echo "  Bridge    : ${BRIDGE}"
echo
echo "  CPU       : ${CORES}"
echo "  Memory    : ${MEMORY} MB"
echo "  Swap      : ${SWAP} MB"
echo

ok "Reverse proxy node is ready."
echo
info "Next step:"
echo "  ./add-proxy-host.sh --vmid ${VMID} ..."
echo