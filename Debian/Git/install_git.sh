#!/usr/bin/env bash

# ============================================================
# Git + GitHub CLI Installer / Updater (Debian)
# Style: Andrew 😎
# ============================================================

set -euo pipefail

# -----------------------------
# Colors
# -----------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# -----------------------------
# Logging
# -----------------------------
log_info()  { echo -e "${BLUE}[INFO]${NC} $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_ok()    { echo -e "${GREEN}[OK]${NC}   $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# -----------------------------
# Globals
# -----------------------------
WORKDIR="/usr/local/src/git-build"
BACKPORTS_TARGET=""
TMP_DIR="/tmp/git-install"

# -----------------------------
# Detect backports
# -----------------------------
detect_backports() {
    if apt-cache policy | grep -q backports; then
        BACKPORTS_TARGET="-t $(apt-cache policy | grep backports | head -n1 | awk '{print $1}')"
        log_info "Backports detected: $BACKPORTS_TARGET"
    else
        log_warn "No backports detected"
    fi
}

# -----------------------------
# Install dependencies
# -----------------------------
install_dependencies() {
    log_info "Installing dependencies..."

    sudo apt update

    if apt-cache policy | grep -q backports; then
        log_info "Using backports for curl dependencies"

        sudo apt install -y -t trixie-backports \
            libcurl4-openssl-dev
    else
        sudo apt install -y \
            libcurl4-openssl-dev
    fi

    sudo apt install -y \
        build-essential \
        libssl-dev \
        libexpat1-dev \
        gettext \
        zlib1g-dev \
        wget \
        curl \
        jq

    log_ok "Dependencies installed"
}

# -----------------------------
# Get current Git version
# -----------------------------
get_git_current_version() {
    if command -v git >/dev/null 2>&1; then
        git --version | awk '{print $3}'
    else
        echo "not installed"
    fi
}

# -----------------------------
# Get latest Git version
# -----------------------------
get_git_latest_version() {
    curl -s https://api.github.com/repos/git/git/tags | jq -r '.[0].name' | sed 's/^v//'
}

# -----------------------------
# Build & install Git
# -----------------------------
install_git() {
    CURRENT=$(get_git_current_version)
    LATEST=$(get_git_latest_version)

    log_info "Git current: $CURRENT"
    log_info "Git latest : $LATEST"

    if [ "$CURRENT" = "$LATEST" ]; then
        log_ok "Git already up to date"
        return
    fi

    log_info "Updating Git from $CURRENT to $LATEST..."

    mkdir -p "$WORKDIR"
    mkdir -p "$TMP_DIR"

    cd "$WORKDIR"

    TAR="git-${LATEST}.tar.gz"
    URL="https://github.com/git/git/archive/refs/tags/v${LATEST}.tar.gz"

    log_info "Downloading Git source..."
    wget -q --show-progress -O "$TAR" "$URL"

    rm -rf "git-${LATEST}"
    tar -xzf "$TAR"
    cd "git-${LATEST}"

    log_info "Building Git..."
    make prefix=/usr/local all -j"$(nproc)"

    log_info "Installing Git..."
    sudo make prefix=/usr/local install

    log_ok "Git updated to $LATEST"
}

# -----------------------------
# Get GitHub CLI current version
# -----------------------------
get_gh_current_version() {
    if command -v gh >/dev/null 2>&1; then
        gh --version | head -n1 | awk '{print $3}'
    else
        echo "not installed"
    fi
}

# -----------------------------
# Get GitHub CLI latest version
# -----------------------------
get_gh_latest_version() {
    curl -s https://api.github.com/repos/cli/cli/releases/latest | jq -r .tag_name
}

# -----------------------------
# Install / update GitHub CLI
# -----------------------------
install_gh() {
    CURRENT=$(get_gh_current_version)
    LATEST=$(get_gh_latest_version)
    LATEST_CLEAN="${LATEST#v}"

    log_info "GitHub CLI current: $CURRENT"
    log_info "GitHub CLI latest : $LATEST"

    if [ "$CURRENT" = "$LATEST_CLEAN" ]; then
        log_ok "GitHub CLI already up to date"
        return
    fi

    log_info "Installing GitHub CLI..."

    mkdir -p "$TMP_DIR"
    DEB="${TMP_DIR}/gh_${LATEST_CLEAN}.deb"

    URL="https://github.com/cli/cli/releases/download/${LATEST}/gh_${LATEST_CLEAN}_linux_amd64.deb"

    log_info "Downloading GitHub CLI..."
    wget -q --show-progress -O "$DEB" "$URL"

    log_info "Installing package..."
    sudo apt install -y "$DEB"

    rm -f "$DEB"

    log_ok "GitHub CLI installed: $LATEST"
}

# -----------------------------
# Cleanup
# -----------------------------
cleanup() {
    log_info "Cleaning up..."
    sudo apt autoremove -y >/dev/null 2>&1 || true
    log_ok "Cleanup completed"
}

# -----------------------------
# Main
# -----------------------------
main() {
    log_info "Starting Git & GitHub CLI updater..."

    detect_backports
    install_dependencies
    install_git
    install_gh
    cleanup

    log_ok "All tasks completed successfully"
}

main "$@"