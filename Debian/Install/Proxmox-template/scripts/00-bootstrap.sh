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
info "Installing and configuring locale..."

apt-get install -y --no-install-recommends locales

if ! grep -Eq '^en_US\.UTF-8 UTF-8' /etc/locale.gen; then
    sed -i \
        's/^# *en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' \
        /etc/locale.gen
fi

locale-gen en_US.UTF-8

update-locale LANG=en_US.UTF-8

export LANG=en_US.UTF-8

ok "Locale configured: en_US.UTF-8"

info "Installing base packages..."
apt-get install -y --no-install-recommends \
  ca-certificates curl wget git rsync unzip zip \
  openssl gnupg jq gawk fzf tree bat \
  vim-tiny less procps htop lsof \
  iproute2 iputils-ping dnsutils traceroute tcpdump \
  netcat-openbsd socat \
  systemd-sysv cron logrotate

ok "Bootstrap packages installed."

info "Configuring administrator PATH..."

cat > /etc/profile.d/local-path.sh <<'EOF'
# Include locally installed administrator commands.
case ":${PATH}:" in
    *:/usr/local/sbin:*) ;;
    *) PATH="/usr/local/sbin:${PATH}" ;;
esac

case ":${PATH}:" in
    *:/usr/local/bin:*) ;;
    *) PATH="/usr/local/bin:${PATH}" ;;
esac

export PATH
EOF

chmod 0644 /etc/profile.d/local-path.sh

ok "Administrator PATH configured."