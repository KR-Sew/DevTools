#!/usr/bin/env bash
set -Eeuo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

info() { echo -e "${BLUE}[INFO]${NC} $*"; }
ok()   { echo -e "${GREEN}[ OK ]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
die()  { echo -e "${RED}[FAIL]${NC} $*" >&2; exit 1; }

[[ $EUID -eq 0 ]] || die "Run as root."

export DEBIAN_FRONTEND=noninteractive

info "Updating Debian package index..."
apt-get update

info "Installing base packages..."
apt-get install -y --no-install-recommends \
  ca-certificates curl wget git rsync unzip zip \
  openssl gnupg jq gawk fzf tree bat \
  vim-tiny less procps htop lsof \
  iproute2 iputils-ping dnsutils traceroute tcpdump \
  netcat-openbsd socat \
  systemd-sysv cron logrotate

ok "Bootstrap packages installed."
