#!/usr/bin/env bash

set -Eeuo pipefail

VMID=""
DOMAIN=""
BACKEND=""
EMAIL=""

BACKEND_VERIFY="auto"
BACKEND_SNI=""

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

info() { echo -e "${BLUE}[INFO]${NC} $*"; }
ok()   { echo -e "${GREEN}[ OK ]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
fail() { echo -e "${RED}[FAIL]${NC} $*" >&2; }

die() {
    fail "$*"
    exit 1
}

section() {
    echo
    echo -e "${CYAN}$*${NC}"
    printf '%*s\n' "${#1}" '' | tr ' ' '-'
}

usage() {
    cat <<EOF

Add NGINX Reverse Proxy Host

Usage:

  sudo $0 \\
      --vmid ID \\
      --domain DOMAIN \\
      --backend URL \\
      --email EMAIL

Examples:

  HTTP backend:

    sudo $0 \\
        --vmid 201 \\
        --domain cloud.example.com \\
        --backend http://10.10.205.50:8080 \\
        --email admin@example.com

  HTTPS backend using DNS:

    sudo $0 \\
        --vmid 201 \\
        --domain cloud.example.com \\
        --backend https://cloud01.internal.example:443 \\
        --email admin@example.com

  HTTPS backend by IP with explicit SNI:

    sudo $0 \\
        --vmid 201 \\
        --domain cloud.example.com \\
        --backend https://10.10.205.50:443 \\
        --backend-sni cloud01.internal.example \\
        --email admin@example.com

Options:

  --vmid ID
  --domain DOMAIN
  --backend URL
  --email EMAIL

  --backend-sni NAME
        Explicit TLS SNI/certificate name for HTTPS upstream.

  --no-backend-verify
        Disable TLS certificate verification for HTTPS upstream.
        Not recommended.

  -h, --help
EOF
}

ct_exec() {
    pct exec "$VMID" -- "$@"
}

ct_bash() {
    pct exec "$VMID" -- /bin/bash -c "$1"
}

is_ip() {
    [[ "$1" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --vmid)
            VMID="$2"
            shift 2
            ;;
        --domain)
            DOMAIN="$2"
            shift 2
            ;;
        --backend)
            BACKEND="$2"
            shift 2
            ;;
        --email)
            EMAIL="$2"
            shift 2
            ;;
        --backend-sni)
            BACKEND_SNI="$2"
            shift 2
            ;;
        --no-backend-verify)
            BACKEND_VERIFY="no"
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            die "Unknown parameter: $1"
            ;;
    esac
done

echo
echo "Add NGINX Reverse Proxy Host"
echo "============================"

[[ $EUID -eq 0 ]] ||
    die "Run this script as root."

[[ -n "$VMID" ]]   || die "--vmid is required."
[[ -n "$DOMAIN" ]] || die "--domain is required."
[[ -n "$BACKEND" ]] || die "--backend is required."
[[ -n "$EMAIL" ]]  || die "--email is required."

[[ "$DOMAIN" =~ ^[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]] ||
    die "Invalid domain: ${DOMAIN}"

[[ "$EMAIL" =~ ^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$ ]] ||
    die "Invalid email: ${EMAIL}"

[[ "$BACKEND" =~ ^https?:// ]] ||
    die "Backend must use http:// or https://"

pct status "$VMID" &>/dev/null ||
    die "CT ${VMID} does not exist."

[[ "$(pct status "$VMID" | awk '{print $2}')" == "running" ]] ||
    die "CT ${VMID} is not running."

# ------------------------------------------------------------------------------
# Parse backend
# ------------------------------------------------------------------------------

BACKEND_SCHEME="${BACKEND%%://*}"
BACKEND_AUTHORITY="${BACKEND#*://}"
BACKEND_AUTHORITY="${BACKEND_AUTHORITY%%/*}"
BACKEND_HOST="${BACKEND_AUTHORITY%%:*}"

section "Proxy host"

ok "Domain: ${DOMAIN}"
ok "Backend: ${BACKEND}"
ok "Protocol: ${BACKEND_SCHEME}"

# ------------------------------------------------------------------------------
# Determine HTTPS upstream policy
# ------------------------------------------------------------------------------

SSL_OPTIONS=""

if [[ "$BACKEND_SCHEME" == "https" ]]; then

    if [[ -z "$BACKEND_SNI" ]] && ! is_ip "$BACKEND_HOST"; then
        BACKEND_SNI="$BACKEND_HOST"
    fi

    if [[ "$BACKEND_VERIFY" == "auto" ]]; then

        if [[ -n "$BACKEND_SNI" ]]; then
            BACKEND_VERIFY="yes"
        else
            BACKEND_VERIFY="no"
            warn "HTTPS backend uses an IP address without --backend-sni."
            warn "Upstream certificate verification will be disabled."
        fi
    fi

    SSL_OPTIONS+="        proxy_ssl_server_name on;\n"

    if [[ -n "$BACKEND_SNI" ]]; then
        SSL_OPTIONS+="        proxy_ssl_name ${BACKEND_SNI};\n"
    fi

    if [[ "$BACKEND_VERIFY" == "yes" ]]; then
        SSL_OPTIONS+="        proxy_ssl_verify on;\n"
        SSL_OPTIONS+="        proxy_ssl_trusted_certificate /etc/ssl/certs/ca-certificates.crt;\n"
        SSL_OPTIONS+="        proxy_ssl_verify_depth 5;\n"
    else
        SSL_OPTIONS+="        proxy_ssl_verify off;\n"
    fi
fi

# ------------------------------------------------------------------------------
# Backend connectivity
# ------------------------------------------------------------------------------

section "Backend"

info "Checking backend connectivity..."

CURL_OPTIONS=(
    --silent
    --show-error
    --location
    --connect-timeout 5
    --max-time 15
    --output /dev/null
)

if [[ "$BACKEND_SCHEME" == "https" &&
      "$BACKEND_VERIFY" == "no" ]]; then
    CURL_OPTIONS+=(--insecure)
fi

if ct_exec curl "${CURL_OPTIONS[@]}" "$BACKEND"; then
    ok "Backend is reachable."
else
    die "Backend connectivity test failed."
fi

# ------------------------------------------------------------------------------
# ACME webroot
# ------------------------------------------------------------------------------

section "HTTP"

ct_exec mkdir -p \
    /var/www/letsencrypt/.well-known/acme-challenge

ct_exec chown -R \
    www-data:www-data \
    /var/www/letsencrypt

VHOST="/etc/nginx/sites-available/${DOMAIN}.conf"
VHOST_ENABLED="/etc/nginx/sites-enabled/${DOMAIN}.conf"

if ct_exec test -e "$VHOST"; then
    die "A configuration already exists for ${DOMAIN}."
fi

info "Creating HTTP virtual host..."

ct_bash "cat > '${VHOST}' <<'EOF'
server {
    listen 80;
    listen [::]:80;

    server_name ${DOMAIN};

    access_log /var/log/nginx/${DOMAIN}.access.log;
    error_log  /var/log/nginx/${DOMAIN}.error.log;

    location ^~ /.well-known/acme-challenge/ {
        root /var/www/letsencrypt;
        default_type text/plain;
        try_files \$uri =404;
    }

    location / {
        proxy_pass ${BACKEND};

        proxy_http_version 1.1;

        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;

        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \"upgrade\";
    }
}
EOF"

ct_exec ln -s \
    "$VHOST" \
    "$VHOST_ENABLED"

ct_exec nginx -t
ct_exec systemctl reload nginx

ok "HTTP virtual host enabled."

# ------------------------------------------------------------------------------
# DNS check
# ------------------------------------------------------------------------------

section "DNS"

PUBLIC_IP="$(
    ct_exec getent ahostsv4 "$DOMAIN" 2>/dev/null |
        awk 'NR == 1 {print $1}' ||
    true
)"

[[ -n "$PUBLIC_IP" ]] ||
    die "${DOMAIN} does not resolve."

ok "${DOMAIN} resolves to ${PUBLIC_IP}"

warn "DNS resolution alone does not prove that TCP/80 reaches this proxy."

# ------------------------------------------------------------------------------
# Certificate
# ------------------------------------------------------------------------------

section "Let's Encrypt"

info "Requesting certificate..."

ct_exec certbot certonly \
    --webroot \
    --webroot-path /var/www/letsencrypt \
    --domain "$DOMAIN" \
    --email "$EMAIL" \
    --agree-tos \
    --non-interactive \
    --keep-until-expiring

CERT="/etc/letsencrypt/live/${DOMAIN}/fullchain.pem"
KEY="/etc/letsencrypt/live/${DOMAIN}/privkey.pem"

ct_exec test -f "$CERT" ||
    die "Certificate was not created."

ct_exec test -f "$KEY" ||
    die "Private key was not created."

ok "Certificate issued."

# ------------------------------------------------------------------------------
# HTTPS configuration
# ------------------------------------------------------------------------------

section "HTTPS"

info "Installing HTTPS configuration..."

ct_bash "cat > '${VHOST}' <<EOF
server {
    listen 80;
    listen [::]:80;

    server_name ${DOMAIN};

    location ^~ /.well-known/acme-challenge/ {
        root /var/www/letsencrypt;
        default_type text/plain;
        try_files \\\$uri =404;
    }

    location / {
        return 301 https://\\\$host\\\$request_uri;
    }
}

server {
    listen 443 ssl;
    listen [::]:443 ssl;

    server_name ${DOMAIN};

    ssl_certificate ${CERT};
    ssl_certificate_key ${KEY};

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 1d;

    access_log /var/log/nginx/${DOMAIN}.access.log;
    error_log  /var/log/nginx/${DOMAIN}.error.log;

    location / {
        proxy_pass ${BACKEND};

        proxy_http_version 1.1;

        proxy_set_header Host \\\$host;
        proxy_set_header X-Real-IP \\\$remote_addr;
        proxy_set_header X-Forwarded-For \\\$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;

        proxy_set_header Upgrade \\\$http_upgrade;
        proxy_set_header Connection \"upgrade\";

$(printf '%b' "$SSL_OPTIONS")
    }
}
EOF"

ct_exec nginx -t
ct_exec systemctl reload nginx

ok "HTTPS virtual host enabled."
ok "HTTP -> HTTPS redirect enabled."

# ------------------------------------------------------------------------------
# Final check
# ------------------------------------------------------------------------------

section "Result"

echo
echo "  Public URL : https://${DOMAIN}"
echo "  Backend    : ${BACKEND}"

if [[ "$BACKEND_SCHEME" == "https" ]]; then
    echo "  Upstream TLS verification : ${BACKEND_VERIFY}"

    if [[ -n "$BACKEND_SNI" ]]; then
        echo "  Upstream TLS name         : ${BACKEND_SNI}"
    fi
fi

echo

ok "Proxy host ${DOMAIN} successfully deployed."