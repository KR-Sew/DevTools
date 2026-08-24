#!/usr/bin/env bash
#
# install-3proxy.sh
# Install the latest stable numeric 3proxy tag from GitHub on Debian/Ubuntu.
#
# The script:
#   - installs build dependencies
#   - discovers the newest stable numeric Git tag (for example 0.9.7)
#   - builds 3proxy with OpenSSL + PCRE2 support
#   - installs the binary under /usr/local/3proxy
#   - creates a safe localhost-only starter configuration
#   - creates and enables a systemd service
#   - records the installed version for future updates
#

set -Eeuo pipefail

# -----------------------------------------------------------------------------
# Settings
# -----------------------------------------------------------------------------

REPO_URL="https://github.com/3proxy/3proxy.git"
INSTALL_DIR="/usr/local/3proxy"
BIN_DIR="${INSTALL_DIR}/bin"
CONF_DIR="${INSTALL_DIR}/conf"
CONFIG_FILE="${CONF_DIR}/3proxy.cfg"
VERSION_FILE="${INSTALL_DIR}/.installed-version"
SOURCE_ROOT="/usr/local/src"
SERVICE_FILE="/etc/systemd/system/3proxy.service"
SERVICE_NAME="3proxy"

# -----------------------------------------------------------------------------
# Colors
# -----------------------------------------------------------------------------

if [[ -t 1 ]]; then
    RED=$'\033[0;31m'
    GREEN=$'\033[0;32m'
    YELLOW=$'\033[1;33m'
    BLUE=$'\033[0;34m'
    CYAN=$'\033[0;36m'
    BOLD=$'\033[1m'
    RESET=$'\033[0m'
else
    RED=""
    GREEN=""
    YELLOW=""
    BLUE=""
    CYAN=""
    BOLD=""
    RESET=""
fi

# -----------------------------------------------------------------------------
# Output helpers
# -----------------------------------------------------------------------------

info()    { printf '%s[INFO]%s %s\n'    "$CYAN"   "$RESET" "$*"; }
success() { printf '%s[ OK ]%s %s\n'    "$GREEN"  "$RESET" "$*"; }
warn()    { printf '%s[WARN]%s %s\n'    "$YELLOW" "$RESET" "$*"; }
error()   { printf '%s[FAIL]%s %s\n'    "$RED"    "$RESET" "$*" >&2; }
section() { printf '\n%s==> %s%s\n'     "$BOLD$BLUE" "$*" "$RESET"; }

die() {
    error "$*"
    exit 1
}

on_error() {
    local exit_code=$?
    error "Installation failed at line ${BASH_LINENO[0]} (exit code ${exit_code})."
    exit "$exit_code"
}

trap on_error ERR

# -----------------------------------------------------------------------------
# Checks
# -----------------------------------------------------------------------------

require_root() {
    [[ $EUID -eq 0 ]] || die "Run this script as root: sudo $0"
}

check_platform() {
    [[ -r /etc/os-release ]] || die "Unable to identify this Linux distribution."

    # shellcheck disable=SC1091
    source /etc/os-release

    case "${ID:-}" in
        debian|ubuntu)
            success "Supported distribution detected: ${PRETTY_NAME:-$ID}"
            ;;
        *)
            die "This script currently supports Debian and Ubuntu only. Detected: ${PRETTY_NAME:-unknown}"
            ;;
    esac
}

check_existing_installation() {
    if [[ -x "${BIN_DIR}/3proxy" ]]; then
        die "3proxy is already installed at ${BIN_DIR}/3proxy. Use update-3proxy.sh instead."
    fi
}

# -----------------------------------------------------------------------------
# Dependencies
# -----------------------------------------------------------------------------

install_dependencies() {
    section "Installing build dependencies"

    export DEBIAN_FRONTEND=noninteractive

    apt-get update
    apt-get install -y \
        ca-certificates \
        git \
        build-essential \
        pkg-config \
        libssl-dev \
        libpcre2-dev

    success "Build dependencies are installed."
}

# -----------------------------------------------------------------------------
# GitHub version discovery
# -----------------------------------------------------------------------------

get_latest_version() {
    local latest

    latest="$(
        git ls-remote --tags --refs "$REPO_URL" \
        | awk -F/ '{print $3}' \
        | sed 's/^v//' \
        | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' \
        | sort -V \
        | tail -n 1
    )"

    [[ -n "$latest" ]] || die "Could not determine the latest stable 3proxy Git tag."

    printf '%s\n' "$latest"
}

# -----------------------------------------------------------------------------
# Build
# -----------------------------------------------------------------------------

build_3proxy() {
    local version="$1"
    local source_dir="${SOURCE_ROOT}/3proxy-${version}"

    section "Building 3proxy ${version}"

    mkdir -p "$SOURCE_ROOT"
    rm -rf "$source_dir"

    info "Cloning Git tag ${version}..."
    git clone \
        --depth 1 \
        --branch "$version" \
        "$REPO_URL" \
        "$source_dir"

    info "Compiling with $(nproc) CPU thread(s)..."
    make -C "$source_dir" -f Makefile.Linux -j"$(nproc)"

    [[ -x "${source_dir}/bin/3proxy" ]] \
        || die "Build completed but ${source_dir}/bin/3proxy was not created."

    if ldd "${source_dir}/bin/3proxy" 2>/dev/null | grep -q 'not found'; then
        ldd "${source_dir}/bin/3proxy" >&2
        die "The newly built binary has unresolved library dependencies."
    fi

    success "3proxy ${version} compiled successfully."
}

# -----------------------------------------------------------------------------
# Installation
# -----------------------------------------------------------------------------

install_binary() {
    local version="$1"
    local source_dir="${SOURCE_ROOT}/3proxy-${version}"

    section "Installing 3proxy binary"

    install -d -m 0755 "$BIN_DIR" "$CONF_DIR"
    install -o root -g root -m 0755 \
        "${source_dir}/bin/3proxy" \
        "${BIN_DIR}/3proxy"

    printf '%s\n' "$version" > "$VERSION_FILE"
    chmod 0644 "$VERSION_FILE"

    success "Installed ${BIN_DIR}/3proxy"
}

create_default_config() {
    section "Creating starter configuration"

    if [[ -e "$CONFIG_FILE" ]]; then
        warn "Configuration already exists; leaving it untouched: ${CONFIG_FILE}"
        return
    fi

    cat > "$CONFIG_FILE" <<'EOF'
# -----------------------------------------------------------------------------
# 3proxy starter configuration
#
# Safe default: HTTP and SOCKS listen on localhost only.
# Change -i127.0.0.1 only after configuring authentication and firewall rules.
# -----------------------------------------------------------------------------

nscache 65536

timeouts 1 5 30 60 180 1800 15 60

auth none
allow *

# HTTP proxy
proxy -p3128 -i127.0.0.1

# SOCKS4/SOCKS5 proxy
socks -p1080 -i127.0.0.1

flush
EOF

    chmod 0640 "$CONFIG_FILE"

    success "Created ${CONFIG_FILE}"
    warn "The starter config listens only on 127.0.0.1 for safety."
    warn "Edit ${CONFIG_FILE} before exposing the proxy to your network."
}

create_systemd_service() {
    section "Creating systemd service"

    cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=3Proxy Proxy Server
Wants=network-online.target
After=network-online.target

[Service]
Type=simple
ExecStart=${BIN_DIR}/3proxy ${CONFIG_FILE}
Restart=on-failure
RestartSec=3
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

    chmod 0644 "$SERVICE_FILE"

    systemctl daemon-reload
    systemctl enable "$SERVICE_NAME"

    success "Created and enabled ${SERVICE_NAME}.service"
}

start_and_validate() {
    local version="$1"

    section "Starting 3proxy"

    systemctl restart "$SERVICE_NAME"
    sleep 2

    if ! systemctl is-active --quiet "$SERVICE_NAME"; then
        journalctl -u "$SERVICE_NAME" -n 50 --no-pager || true
        die "3proxy failed to start."
    fi

    success "3proxy ${version} is running."

    printf '\n'
    systemctl --no-pager --full status "$SERVICE_NAME" || true

    printf '\n'
    info "Listening TCP sockets:"
    ss -lntp 2>/dev/null | grep 3proxy || warn "No TCP listener was shown by ss."
}

print_summary() {
    local version="$1"

    section "Installation completed"

    printf '%sVersion:%s      %s\n' "$BOLD" "$RESET" "$version"
    printf '%sBinary:%s       %s\n' "$BOLD" "$RESET" "${BIN_DIR}/3proxy"
    printf '%sConfig:%s       %s\n' "$BOLD" "$RESET" "$CONFIG_FILE"
    printf '%sService:%s      %s\n' "$BOLD" "$RESET" "$SERVICE_FILE"
    printf '%sSource:%s       %s\n' "$BOLD" "$RESET" "${SOURCE_ROOT}/3proxy-${version}"
    printf '%sVersion file:%s %s\n' "$BOLD" "$RESET" "$VERSION_FILE"
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------

main() {
    section "3proxy installer"

    require_root
    check_platform
    check_existing_installation
    install_dependencies

    local latest_version
    latest_version="$(get_latest_version)"

    info "Latest stable GitHub tag: ${latest_version}"

    build_3proxy "$latest_version"
    install_binary "$latest_version"
    create_default_config
    create_systemd_service
    start_and_validate "$latest_version"
    print_summary "$latest_version"
}

main "$@"
