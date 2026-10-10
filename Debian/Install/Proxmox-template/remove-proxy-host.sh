#!/usr/bin/env bash
set -Eeuo pipefail
BLUE=$'\033[0;34m'; GREEN=$'\033[0;32m'; YELLOW=$'\033[0;33m'; RED=$'\033[0;31m'; NC=$'\033[0m'
info(){ printf '%s[INFO]%s %s\n' "$BLUE" "$NC" "$*"; }
ok(){ printf '%s[ OK ]%s %s\n' "$GREEN" "$NC" "$*"; }
warn(){ printf '%s[WARN]%s %s\n' "$YELLOW" "$NC" "$*"; }
die(){ printf '%s[FAIL]%s %s\n' "$RED" "$NC" "$*" >&2; exit 1; }
usage(){ cat <<USAGE
Usage: sudo $0 --vmid CTID --domain example.com [--purge] [--delete-cert] [--yes]
Default: disable NGINX vhost only; preserve configuration and certificate.
--purge       Delete the NGINX vhost configuration after disabling it.
--delete-cert Delete the matching Certbot certificate (requires --purge).
--yes         Skip interactive confirmation.
USAGE
}
VMID=''; DOMAIN=''; PURGE=0; DELETE_CERT=0; YES=0
while (($#)); do
  case "$1" in
    --vmid) (($#>=2)) || die 'Missing VMID'; VMID=$2; shift 2;;
    --domain) (($#>=2)) || die 'Missing domain'; DOMAIN=$2; shift 2;;
    --purge) PURGE=1; shift;;
    --delete-cert) DELETE_CERT=1; shift;;
    --yes) YES=1; shift;;
    -h|--help) usage; exit 0;;
    *) die "Unknown argument: $1";;
  esac
done
[[ $EUID -eq 0 ]] || die 'Run as root on Proxmox.'
[[ $VMID =~ ^[0-9]+$ ]] || die 'Provide numeric --vmid.'
[[ $DOMAIN =~ ^[A-Za-z0-9]([A-Za-z0-9.-]*[A-Za-z0-9])?$ && $DOMAIN == *.* && $DOMAIN != *..* ]] || die 'Invalid domain.'
(( ! DELETE_CERT || PURGE )) || die '--delete-cert requires --purge.'
command -v pct >/dev/null || die 'pct is unavailable.'
[[ $(pct status "$VMID" 2>/dev/null) == *running* ]] || die "CT $VMID is not running."
info "CT: $VMID | Domain: $DOMAIN"
if ((PURGE)); then warn 'NGINX vhost configuration will be deleted after a successful validation.'; else info 'Only the enabled symlink will be removed.'; fi
if ((DELETE_CERT)); then warn 'Certbot certificate deletion requested (after successful NGINX reload).'; else info 'Certificate will be preserved.'; fi
if (( ! YES )); then
  [[ -t 0 ]] || die 'Non-interactive mode requires --yes.'
  read -r -p "Type '$DOMAIN' to confirm: " answer
  [[ $answer == "$DOMAIN" ]] || die 'Cancelled.'
fi
# The guest script uses fixed, validated arguments; do not interpolate shell code.
pct exec "$VMID" -- bash -s -- "$DOMAIN" "$PURGE" "$DELETE_CERT" <<'INNER'
set -Eeuo pipefail
DOMAIN=$1; PURGE=$2; DELETE_CERT=$3
AVAILABLE="/etc/nginx/sites-available/$DOMAIN.conf"
ENABLED="/etc/nginx/sites-enabled/$DOMAIN.conf"
[[ -f "$AVAILABLE" ]] || { echo "[FAIL] Config missing: $AVAILABLE" >&2; exit 1; }
[[ ! -e "$ENABLED" || -L "$ENABLED" ]] || { echo "[FAIL] Enabled path is not a symlink: $ENABLED" >&2; exit 1; }
if [[ -L "$ENABLED" ]]; then
  target=$(readlink -f "$ENABLED" || true)
  [[ "$target" == "$AVAILABLE" ]] || { echo '[FAIL] Enabled symlink points to unexpected config.' >&2; exit 1; }
fi
nginx -t || exit 1
backup=$(mktemp -d /tmp/proxy-remove.XXXXXXXX)
was_enabled=0
[[ -L "$ENABLED" ]] && was_enabled=1
cp -a "$AVAILABLE" "$backup/vhost.conf"
rollback(){
  cp -a "$backup/vhost.conf" "$AVAILABLE"
  if ((was_enabled)); then ln -sfn "$AVAILABLE" "$ENABLED"; else rm -f "$ENABLED"; fi
  nginx -t && systemctl reload nginx || true
  echo '[WARN] NGINX configuration restored after failure.' >&2
}
trap rollback ERR
rm -f "$ENABLED"
nginx -t
systemctl reload nginx
if ((PURGE)); then
  rm -f "$AVAILABLE"
  nginx -t
  systemctl reload nginx
fi
trap - ERR
printf '[ OK ] Vhost disabled: %s\n' "$DOMAIN"
if ((PURGE)); then printf '[ OK ] Vhost config removed: %s\n' "$AVAILABLE"; fi
if ((DELETE_CERT)); then
  # Do not delete a certificate still referenced by another NGINX config.
  if grep -R -F -q "/etc/letsencrypt/live/$DOMAIN/" /etc/nginx/sites-available /etc/nginx/conf.d 2>/dev/null; then
    echo '[WARN] Certificate is referenced by another NGINX config; preserving it.'
  elif certbot certificates --cert-name "$DOMAIN" 2>/dev/null | grep -F -q "Certificate Name: $DOMAIN"; then
    certbot delete --cert-name "$DOMAIN" --non-interactive
    printf '[ OK ] Certbot certificate deleted: %s\n' "$DOMAIN"
  else
    echo '[WARN] Matching Certbot certificate not found; nothing to delete.'
  fi
fi
rm -rf "$backup"
INNER
ok "Removal operation completed for $DOMAIN."
