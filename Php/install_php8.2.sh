#!/bin/bash

set -e

PHP_VERSION="8.2"

echo "➡️ Installing PHP $PHP_VERSION..."

# === Update and install prerequisites ===
sudo apt update
sudo apt install -y software-properties-common lsb-release ca-certificates apt-transport-https curl gnupg

# === Add Ondřej Surý's PHP PPA if not already added ===
if ! grep -q "^deb .*/ondrej/php" /etc/apt/sources.list /etc/apt/sources.list.d/* 2>/dev/null; then
    echo "➕ Adding PHP PPA..."
    sudo add-apt-repository -y ppa:ondrej/php
    sudo apt update
else
    echo "ℹ️ PHP PPA already exists. Skipping..."
fi

# === Install PHP and common extensions ===
sudo apt install -y php${PHP_VERSION} php${PHP_VERSION}-cli php${PHP_VERSION}-fpm php${PHP_VERSION}-common \
    php${PHP_VERSION}-mbstring php${PHP_VERSION}-xml php${PHP_VERSION}-curl php${PHP_VERSION}-zip php${PHP_VERSION}-pgsql

# === Verify Installation ===
echo "✅ Installed PHP version:"
php -v

echo "✅ Installed PHP-FPM status:"
systemctl status php${PHP_VERSION}-fpm --no-pager
