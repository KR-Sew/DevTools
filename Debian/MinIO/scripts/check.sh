#!/usr/bin/env bash
set -euo pipefail

API_URL="${API_URL:-https://s3.your_domaine.name}"
CONSOLE_URL="${CONSOLE_URL:-https://s3-console.your_domain.name}"

ok()   { printf '\033[1;32m[ OK ]\033[0m %s\n' "$*"; }
info() { printf '\033[1;34m[INFO]\033[0m %s\n' "$*"; }
fail() { printf '\033[1;31m[FAIL]\033[0m %s\n' "$*" >&2; exit 1; }

info "Checking Docker Compose configuration..."
docker compose config --quiet || fail "Docker Compose configuration is invalid."
ok "Docker Compose configuration is valid."

info "Checking MinIO container..."
docker compose ps
docker inspect -f '{{.State.Status}}' minio | grep -qx running || fail "MinIO is not running."
ok "MinIO container is running."

info "Checking local API..."
curl -fsS http://127.0.0.1:9000/minio/health/live >/dev/null || fail "Local MinIO API failed."
ok "Local MinIO API is healthy."

info "Checking public S3 API..."
curl -fsS "${API_URL}/minio/health/live" >/dev/null || fail "Public S3 API failed."
ok "Public S3 API is healthy."

info "Checking console..."
curl -fsSI "${CONSOLE_URL}/" >/dev/null || fail "Console endpoint failed."
ok "Console endpoint is reachable."

info "Checking listeners..."
ss -tln | grep -E '127\.0\.0\.1:(9000|9001)' || fail "Expected localhost listeners not found."
ok "MinIO ports are bound to localhost."
