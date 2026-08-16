#!/usr/bin/env bash
set -Eeuo pipefail

VERSION="0.9.6"
INSTALL_DIR="/usr/local/3proxy"
SOURCE_DIR="/usr/local/src/3proxy-${VERSION}"
BINARY="${INSTALL_DIR}/bin/3proxy"
BACKUP="${BINARY}.pre-${VERSION}-$(date +%F-%H%M%S)"

if [[ $EUID -ne 0 ]]; then
    echo "Run this script as root."
    exit 1
fi

if [[ ! -x "$BINARY" ]]; then
    echo "Existing 3proxy binary not found: $BINARY"
    exit 1
fi

if [[ ! -f "${INSTALL_DIR}/conf/3proxy.cfg" ]]; then
    echo "Configuration not found: ${INSTALL_DIR}/conf/3proxy.cfg"
    exit 1
fi

echo "Installing build dependencies..."
apt-get update
apt-get install -y \
    git \
    build-essential \
    cmake \
    pkg-config \
    libpcre2-dev

echo "Downloading 3proxy ${VERSION}..."
mkdir -p /usr/local/src
rm -rf "$SOURCE_DIR"

git clone \
    --depth 1 \
    --branch "$VERSION" \
    https://github.com/3proxy/3proxy.git \
    "$SOURCE_DIR"

echo "Compiling..."
make -C "$SOURCE_DIR" -f Makefile.Linux

NEW_BINARY="${SOURCE_DIR}/bin/3proxy"

if [[ ! -x "$NEW_BINARY" ]]; then
    echo "Compiled binary was not created: $NEW_BINARY"
    exit 1
fi

echo "Backing up current binary to $BACKUP..."
cp -a "$BINARY" "$BACKUP"

echo "Stopping 3proxy..."
systemctl stop 3proxy

echo "Installing new binary..."
install \
    --owner=root \
    --group=root \
    --mode=0755 \
    "$NEW_BINARY" \
    "${BINARY}.new"

mv "${BINARY}.new" "$BINARY"

echo "Starting 3proxy..."
if systemctl start 3proxy && systemctl is-active --quiet 3proxy; then
    echo
    echo "3proxy ${VERSION} was installed successfully."
    systemctl --no-pager --full status 3proxy
else
    echo
    echo "Upgrade failed. Restoring the previous executable..."

    systemctl stop 3proxy 2>/dev/null || true
    cp -a "$BACKUP" "$BINARY"
    systemctl start 3proxy

    journalctl -u 3proxy -n 50 --no-pager
    exit 1
fi