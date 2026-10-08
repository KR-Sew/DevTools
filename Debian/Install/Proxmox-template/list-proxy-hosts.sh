#!/usr/bin/env bash
set -Eeuo pipefail
BLUE=$'\033[0;34m'; GREEN=$'\033[0;32m'; RED=$'\033[0;31m'; NC=$'\033[0m'
info(){ printf '%s[INFO]%s %s\n' "$BLUE" "$NC" "$*"; }
ok(){ printf '%s[ OK ]%s %s\n' "$GREEN" "$NC" "$*"; }
die(){ printf '%s[FAIL]%s %s\n' "$RED" "$NC" "$*" >&2; exit 1; }
usage(){ echo "Usage: sudo $0 --vmid CTID"; }
VMID=''
while (($#)); do case "$1" in --vmid) (($#>=2)) || die 'Missing VMID'; VMID=$2; shift 2;; -h|--help) usage; exit 0;; *) die "Unknown argument: $1";; esac; done
[[ $EUID -eq 0 ]] || die 'Run as root on Proxmox.'
[[ $VMID =~ ^[0-9]+$ ]] || die 'Provide numeric --vmid.'
command -v pct >/dev/null || die 'pct is unavailable.'
[[ $(pct status "$VMID" 2>/dev/null) == *running* ]] || die "CT $VMID is not running."
info "NGINX proxy hosts in CT $VMID"
pct exec "$VMID" -- bash -s <<'INNER'
set -u
shopt -s nullglob
printf '%-32s %-8s %-35s %-12s %s\n' 'DOMAIN' 'ENABLED' 'BACKEND' 'CERT' 'EXPIRY (UTC)'
printf '%s\n' '--------------------------------------------------------------------------------------------------------------'
count=0
for file in /etc/nginx/sites-available/*.conf; do
  name=${file##*/}; domain=${name%.conf}
  [[ $domain =~ ^[A-Za-z0-9][A-Za-z0-9.-]*$ ]] || continue
  [[ -f /etc/nginx/sites-enabled/$name ]] && enabled=yes || enabled=no
  backend=$(sed -nE 's/^[[:space:]]*proxy_pass[[:space:]]+([^;]+);.*/\1/p' "$file" | head -n1)
  [[ -n $backend ]] || backend='(none)'
  cert='no'; expiry='-'
  pem="/etc/letsencrypt/live/$domain/fullchain.pem"
  if [[ -f $pem ]]; then
    cert=yes
    expiry=$(openssl x509 -in "$pem" -noout -enddate 2>/dev/null | sed 's/^notAfter=//' || true)
    [[ -n $expiry ]] || expiry='unknown'
  fi
  printf '%-32s %-8s %-35s %-12s %s\n' "$domain" "$enabled" "$backend" "$cert" "$expiry"
  ((count+=1))
done
printf '\nTotal configured hosts: %s\n' "$count"
INNER
ok 'Inventory complete.'
