#!/bin/bash

set -e

# === Configuration ===
NVM_VERSION="v0.39.7"
NVM_DIR="$HOME/.nvm"

echo "Installing NVM $NVM_VERSION..."

# === Install NVM ===
if [ ! -d "$NVM_DIR" ]; then
    curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/$NVM_VERSION/install.sh | bash
else
    echo "NVM is already installed at $NVM_DIR"
fi

# === Load NVM into current shell ===
export NVM_DIR
# shellcheck disable=SC1090
[ -s "$NVM_DIR/nvm.sh" ] && source "$NVM_DIR/nvm.sh"
# shellcheck disable=SC1090
[ -s "$NVM_DIR/bash_completion" ] && source "$NVM_DIR/bash_completion"

# === Verify NVM installation ===
if command -v nvm >/dev/null 2>&1; then
    echo "✅ NVM successfully installed and available as: $(command -v nvm)"
    echo "NVM version: $(nvm --version)"
else
    echo "❌ NVM installation failed or NVM is not in PATH"
    exit 1
fi
