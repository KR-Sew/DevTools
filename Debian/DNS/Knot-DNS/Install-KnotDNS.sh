#!/usr/bin/env bash
set -euo pipefail

# ===============================
# Variables
# ===============================
KNOT_USER="knot"
KNOT_GROUP="knot"
INSTALL_PREFIX="/usr/local"
SRC_DIR="/usr/local/src"
BUILD_DIR="$SRC_DIR/knotdns-build"
KNOT_LATEST_URL="https://www.knot-dns.cz/download/"
KNOT_VERSION=""

# ===============================
# Logging helpers
# ===============================
log_info()  { echo -e "\e[32m[INFO]\e[0m $1"; }
log_warn()  { echo -e "\e[33m[WARN]\e[0m $1"; }
log_error() { echo -e "\e[31m[ERROR]\e[0m $1"; exit 1; }

# ===============================
# Configure  helper
# ===============================

check_configure_log() {
    local logfile="$1"

    if grep -qEi "^configure: error:" "$logfile"; then
        log_error "Configuration failed."

        grep -Ei "^configure: error:" "$logfile"

        return 1
    fi

    log_info "Configuration completed successfully."
}

# ===============================
# Detect latest version
# ===============================
log_info "Fetching latest Knot DNS version..."
#KNOT_VERSION=$(curl -s https://www.knot-dns.cz/download/ | grep -oP 'knot-\K[0-9]+\.[0-9]+\.[0-9]+')

KNOT_VERSION=$(
    curl -fsSL https://www.knot-dns.cz/download/ |
    grep -m1 -oP 'Knot DNS \K[0-9]+\.[0-9]+\.[0-9]+'
)

log_info "Latest version: ${KNOT_VERSION}"


if [[ -z "$KNOT_VERSION" ]]; then
    log_error "Unable to detect latest version"
fi

log_info "Latest version: $KNOT_VERSION"

# ===============================
# Install build dependencies
# ===============================
log_info "Installing build dependencies..."
apt update -qq
apt install -y \
    build-essential \
    libuv1-dev \
    libgnutls28-dev \
    liblmdb-dev \
    liburcu-dev \
    libedit-dev \
    zlib1g-dev \
    pkg-config \
    autoconf \
    automake \
    libtool \
    meson \
    ninja-build \
    git \
    curl

# ===============================
# Create system user
# ===============================

if ! id "$KNOT_USER" &>/dev/null; then
    log_info "Creating knot system user..."
    useradd -r -s /usr/sbin/nologin -d /var/lib/knot $KNOT_USER
fi

mkdir -p /var/lib/knot
chown -R $KNOT_USER:$KNOT_GROUP /var/lib/knot || true

# ===============================
# Download source
# ===============================
mkdir -p "$BUILD_DIR"
cd "$SRC_DIR"

log_info "Downloading Knot DNS source..."

TARBALL_URL="https://secure.nic.cz/files/knot-dns/knot-${KNOT_VERSION}.tar.xz"

log_info "URL: $TARBALL_URL"

curl -fL -o "knot-${KNOT_VERSION}.tar.xz" "$TARBALL_URL"


tar -xJf "knot-${KNOT_VERSION}.tar.xz"
cd "knot-${KNOT_VERSION}"


# ===============================
# Build
# ===============================

log_info "Configuring build..."

ERRORS=$(grep -Ei "^configure: error:" configure.log || true)

if [[ -z "$ERRORS" ]]; then
    log_info "Configure completed successfully."
else
    log_error "Configure failed:$ERRORS"
    exit 1
fi


if [[ ! -x ./configure ]]; then
    log_error "configure script not found"
fi

./configure \
    --prefix="$INSTALL_PREFIX" \
    --sysconfdir=/etc/knot \
    --localstatedir=/var \
    2>&1 | tee configure.log

check_configure_log configure.log

log_info "Compiling..."
make -j"$(nproc)"

log_info "Installing..."
make install

# ===============================
# Systemd service
# ===============================
log_info "Creating systemd unit..."

cat >/etc/systemd/system/knot.service <<EOF
[Unit]
Description=Knot DNS authoritative server
After=network.target

[Service]
Type=simple
User=$KNOT_USER
Group=$KNOT_GROUP
ExecStart=$INSTALL_PREFIX/sbin/knotd -c /etc/knot/knot.conf
Restart=on-failure
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable knot

log_info "Installation complete."
log_info "Binary location: $INSTALL_PREFIX/sbin/knotd"