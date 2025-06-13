#!/bin/bash

set -e

# === Configuration ===
NODE_VERSION="10.24.1"
NVM_VERSION="v0.39.7"
NVM_DIR="$HOME/.nvm"

echo "Installing Node.js version $NODE_VERSION using NVM..."

# === Install NVM ===
if [ ! -d "$NVM_DIR" ]; then
    echo "NVM not found. Installing NVM $NVM_VERSION..."
    curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/$NVM_VERSION/install.sh | bash
else
    echo "NVM already installed. Skipping NVM installation."
fi

# === Load NVM into the current shell ===
export NVM_DIR
# shellcheck disable=SC1090
[ -s "$NVM_DIR/nvm.sh" ] && source "$NVM_DIR/nvm.sh"
# shellcheck disable=SC1090
[ -s "$NVM_DIR/bash_completion" ] && source "$NVM_DIR/bash_completion"

# === Install Node.js ===
if nvm ls "$NODE_VERSION" >/dev/null 2>&1; then
    echo "Node.js $NODE_VERSION already installed."
else
    echo "Installing Node.js $NODE_VERSION..."
    nvm install "$NODE_VERSION" --latest-npm
fi

nvm use "$NODE_VERSION"
nvm alias default "$NODE_VERSION"

# === Final Verification ===
echo "✅ Node.js version: $(node -v)"
echo "✅ NPM version: $(npm -v)"
