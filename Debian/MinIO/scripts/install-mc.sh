#!/usr/bin/env bash
set -euo pipefail

VERSION="RELEASE.2025-08-13T08-35-41Z"
URL="https://github.com/minio/mc/releases/download/${VERSION}/mc.linux-amd64.${VERSION}"
TMP="$(mktemp)"

ok()   { printf '\033[1;32m[ OK ]\033[0m %s\n' "$*"; }
info() { printf '\033[1;34m[INFO]\033[0m %s\n' "$*"; }

trap 'rm -f "$TMP"' EXIT

info "Downloading MinIO Client ${VERSION}..."
curl -fL "$URL" -o "$TMP"

file "$TMP" | grep -q 'ELF 64-bit' || {
    echo "[FAIL] Download is not an ELF executable." >&2
    exit 1
}

chmod +x "$TMP"
"$TMP" --version

info "Installing /usr/local/bin/mc..."
sudo install -m 0755 "$TMP" /usr/local/bin/mc
ok "Installed: $(command -v mc)"
mc --version
