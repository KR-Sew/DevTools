#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

trap 'rc=$?; echo "[FAIL] line $LINENO: $BASH_COMMAND (exit $rc)" >&2' ERR

SCRIPT_DIR="$(
    cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1
    pwd -P
)"

COMPOSE_DIR="${COMPOSE_DIR:-/mnt/hgsc1/projects/gitlab}"
BACKUP_ROOT="${BACKUP_ROOT:-/mnt/hgsd1/backups/postres_gitlab}"
GITLAB_CONTAINER="${GITLAB_CONTAINER:-gitlab}"
POSTGRES_CONTAINER="${POSTGRES_CONTAINER:-gitlab_postgres}"
GITLAB_DATA="${GITLAB_DATA:-/mnt/hgsc1/projects/gitlab/data}"
GITLAB_CONFIG="${GITLAB_CONFIG:-/mnt/hgsc1/projects/gitlab/config}"

cd "$COMPOSE_DIR"

GITLAB_VERSION="$(docker exec "$GITLAB_CONTAINER" gitlab-rails runner 'puts Gitlab::VERSION')"
GITLAB_VERSION="${GITLAB_VERSION//$'\r'/}"
[[ -n "$GITLAB_VERSION" ]] || { echo "[FAIL] Cannot determine GitLab version." >&2; exit 1; }

PG_DB="$(docker inspect "$POSTGRES_CONTAINER" --format '{{range .Config.Env}}{{println .}}{{end}}' | sed -n 's/^POSTGRES_DB=//p')"
PG_USER="$(docker inspect "$POSTGRES_CONTAINER" --format '{{range .Config.Env}}{{println .}}{{end}}' | sed -n 's/^POSTGRES_USER=//p')"
[[ -n "$PG_DB" && -n "$PG_USER" ]] || { echo "[FAIL] Cannot determine PostgreSQL DB/user." >&2; exit 1; }

STAMP="$(date +%F-%H%M%S)"
BACKUP_DIR="$BACKUP_ROOT/gitlab-$GITLAB_VERSION-$STAMP"
mkdir -p "$BACKUP_DIR"
chmod 700 "$BACKUP_ROOT" "$BACKUP_DIR"

echo "GitLab backup"
echo "============="
echo "Version : $GITLAB_VERSION"
echo "DB      : $PG_DB"
echo "Target  : $BACKUP_DIR"

docker exec "$POSTGRES_CONTAINER" pg_isready -U "$PG_USER" -d "$PG_DB"

echo "[INFO] Creating PostgreSQL custom-format dump..."
# Deliberately no -t: custom-format dump is binary.
docker exec "$POSTGRES_CONTAINER" \
  pg_dump --username="$PG_USER" --dbname="$PG_DB" \
  --format=custom --compress=6 --no-owner --no-acl \
  > "$BACKUP_DIR/$PG_DB.dump"

test -s "$BACKUP_DIR/$PG_DB.dump"

echo "[INFO] Validating PostgreSQL dump..."
docker exec -i "$POSTGRES_CONTAINER" pg_restore --list \
  < "$BACKUP_DIR/$PG_DB.dump" \
  > "$BACKUP_DIR/$PG_DB.dump.list"
test -s "$BACKUP_DIR/$PG_DB.dump.list"

# Record current archives so the script can identify exactly the archive created below.
declare -A BEFORE=()
while IFS= read -r -d '' f; do BEFORE["$f"]=1; done < <(
  find "$GITLAB_DATA/backups" -maxdepth 1 -type f -name '*_gitlab_backup.tar' -print0
)

echo "[INFO] Creating GitLab application backup (DB skipped)..."
docker exec "$GITLAB_CONTAINER" gitlab-backup create SKIP=db

NEW_BACKUP=""
while IFS= read -r -d '' f; do
  if [[ ! -v 'BEFORE[$f]' ]]; then
    NEW_BACKUP="$f"
    break
  fi
done < <(
  find "$GITLAB_DATA/backups" -maxdepth 1 -type f -name '*_gitlab_backup.tar' -print0
)

[[ -n "$NEW_BACKUP" ]] || { echo "[FAIL] New GitLab backup archive not found." >&2; exit 1; }
cp -a "$NEW_BACKUP" "$BACKUP_DIR/"

echo "[INFO] Saving configuration..."
tar --xattrs --acls --numeric-owner \
  -C "$(dirname "$GITLAB_CONFIG")" \
  -czf "$BACKUP_DIR/gitlab-config.tar.gz" \
  "$(basename "$GITLAB_CONFIG")"

test -f "$GITLAB_CONFIG/gitlab-secrets.json"
cp -a "$GITLAB_CONFIG/gitlab-secrets.json" "$BACKUP_DIR/"
[[ -f "$GITLAB_CONFIG/gitlab.rb" ]] && cp -a "$GITLAB_CONFIG/gitlab.rb" "$BACKUP_DIR/" || true
cp -a docker-compose.yml "$BACKUP_DIR/"
cp -a .env "$BACKUP_DIR/"
[[ -f init-gitlab-db.sql ]] && cp -a init-gitlab-db.sql "$BACKUP_DIR/" || true

docker compose config > "$BACKUP_DIR/docker-compose.resolved.yml"
docker inspect "$GITLAB_CONTAINER" --format '{{.Config.Image}}' > "$BACKUP_DIR/gitlab-image.txt"
docker inspect "$POSTGRES_CONTAINER" --format '{{.Config.Image}}' > "$BACKUP_DIR/postgres-image.txt"
docker exec "$GITLAB_CONTAINER" gitlab-rake gitlab:env:info > "$BACKUP_DIR/gitlab-env-info.txt"
docker exec "$POSTGRES_CONTAINER" psql -U "$PG_USER" -d "$PG_DB" -Atc 'SELECT version();' \
  > "$BACKUP_DIR/postgresql-version.txt"

echo "[INFO] Generating SHA-256 checksums..."
(
  cd "$BACKUP_DIR"
  find . -maxdepth 1 -type f ! -name SHA256SUMS -print0 |
    sort -z |
    xargs -0 sha256sum > SHA256SUMS
  sha256sum -c SHA256SUMS
)

echo "[ OK ] Backup completed: $BACKUP_DIR"
