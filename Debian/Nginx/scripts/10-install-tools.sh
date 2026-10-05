#!/usr/bin/env bash
set -Eeuo pipefail
GREEN='\033[0;32m'; BLUE='\033[0;34m'; RED='\033[0;31m'; NC='\033[0m'
info(){ echo -e "${BLUE}[INFO]${NC} $*"; }
ok(){ echo -e "${GREEN}[ OK ]${NC} $*"; }
die(){ echo -e "${RED}[FAIL]${NC} $*" >&2; exit 1; }

[[ $EUID -eq 0 ]] || die "Run as root."

info "Creating convenience command for Debian's batcat..."
if command -v batcat >/dev/null 2>&1; then
  ln -sf /usr/bin/batcat /usr/local/bin/bat
fi

info "Installing useful shell defaults..."
cat >/etc/profile.d/reverse-proxy-tools.sh <<'EOF'
alias ll='ls -alF'
alias nginx-test='nginx -t'
alias nginx-reload='systemctl reload nginx'
EOF

ok "Administration tools configured."
