#!/usr/bin/env bash

set -Eeuo pipefail
umask 077

COMPOSE_DIR='/mnt/hgsc1/projects/gitlab'
BACKUP_ROOT='/mnt/hgsd1/backups/postres_gitlab'
GITLAB_CONTAINER='gitlab'
POSTGRES_CONTAINER='gitlab_postgres'
GITLAB_DATA='/mnt/hgsc1/projects/gitlab/data'
GITLAB_CONFIG='/mnt/hgsc1/projects/gitlab/config'

cd "$COMPOSE_DIR"

GITLAB_VERSION="$(
    docker exec "$GITLAB_CONTAINER" \
        gitlab-rails runner 'puts Gitlab::VERSION'
)"

GITLAB_VERSION="${GITLAB_VERSION//$'\r'/}"

if [[ -z "$GITLAB_VERSION" ]]; then
    echo "ERROR: Could not determine GitLab version." >&2
    exit 1
fi

TIMESTAMP="$(date +%F-%H%M%S)"
BACKUP_DIR="${BACKUP_ROOT}/gitlab-${GITLAB_VERSION}-${TIMESTAMP}"

mkdir -p "$BACKUP_DIR"
chmod 700 "$BACKUP_ROOT" "$BACKUP_DIR"

PG_DB="$(
    docker inspect "$POSTGRES_CONTAINER" \
        --format '{{range .Config.Env}}{{println .}}{{end}}' |
    sed -n 's/^POSTGRES_DB=//p'
)"

PG_USER="$(
    docker inspect "$POSTGRES_CONTAINER" \
        --format '{{range .Config.Env}}{{println .}}{{end}}' |
    sed -n 's/^POSTGRES_USER=//p'
)"

if [[ -z "$PG_DB" || -z "$PG_USER" ]]; then
    echo "ERROR: Could not determine POSTGRES_DB or POSTGRES_USER." >&2
    exit 1
fi

echo "Backup directory: $BACKUP_DIR"
echo "GitLab version:   $GITLAB_VERSION"
echo "Database:         $PG_DB"
echo "Database user:    $PG_USER"

echo
echo "Checking containers..."

docker inspect "$GITLAB_CONTAINER" >/dev/null
docker inspect "$POSTGRES_CONTAINER" >/dev/null

docker exec "$POSTGRES_CONTAINER" \
    pg_isready -U "$PG_USER" -d "$PG_DB"

echo
echo "Creating PostgreSQL 17 custom-format dump..."

docker exec "$POSTGRES_CONTAINER" \
    pg_dump \
        --username="$PG_USER" \
        --dbname="$PG_DB" \
        --format=custom \
        --compress=6 \
        --no-owner \
        --no-acl \
    > "$BACKUP_DIR/${PG_DB}.dump"

test -s "$BACKUP_DIR/${PG_DB}.dump"

echo "Validating PostgreSQL dump..."

docker exec -i "$POSTGRES_CONTAINER" \
    pg_restore --list \
    < "$BACKUP_DIR/${PG_DB}.dump" \
    > "$BACKUP_DIR/${PG_DB}.dump.list"

echo
echo "Creating GitLab backup without database..."

docker exec "$GITLAB_CONTAINER" \
    gitlab-backup create SKIP=db

LATEST_GITLAB_BACKUP="$(
    find "$GITLAB_DATA/backups" \
        -maxdepth 1 \
        -type f \
        -name '*_gitlab_backup.tar' \
        -printf '%T@\t%p\n' |
    sort -n |
    awk -F'\t' '
        {
            latest = $2
        }
        END {
            print latest
        }
    '
)"

if [[ -z "$LATEST_GITLAB_BACKUP" ]]; then
    echo "ERROR: GitLab backup archive was not found." >&2
    exit 1
fi

cp -a "$LATEST_GITLAB_BACKUP" "$BACKUP_DIR/"

echo
echo "Saving GitLab configuration and secrets..."

tar \
    --xattrs \
    --acls \
    --numeric-owner \
    -C "$(dirname "$GITLAB_CONFIG")" \
    -czf "$BACKUP_DIR/gitlab-config.tar.gz" \
    "$(basename "$GITLAB_CONFIG")"

test -f "$GITLAB_CONFIG/gitlab-secrets.json"
cp -a "$GITLAB_CONFIG/gitlab-secrets.json" "$BACKUP_DIR/"

if [[ -f "$GITLAB_CONFIG/gitlab.rb" ]]; then
    cp -a "$GITLAB_CONFIG/gitlab.rb" "$BACKUP_DIR/"
fi

cp -a docker-compose.yml "$BACKUP_DIR/"
cp -a .env "$BACKUP_DIR/"

if [[ -f init-gitlab-db.sql ]]; then
    cp -a init-gitlab-db.sql "$BACKUP_DIR/"
fi

docker compose config \
    > "$BACKUP_DIR/docker-compose.resolved.yml"

docker inspect "$GITLAB_CONTAINER" \
    --format '{{.Config.Image}}' \
    > "$BACKUP_DIR/gitlab-image.txt"

docker inspect "$POSTGRES_CONTAINER" \
    --format '{{.Config.Image}}' \
    > "$BACKUP_DIR/postgres-image.txt"

docker exec "$GITLAB_CONTAINER" \
    gitlab-rake gitlab:env:info \
    > "$BACKUP_DIR/gitlab-env-info.txt"

docker exec "$POSTGRES_CONTAINER" \
    psql -U "$PG_USER" -d "$PG_DB" \
    -Atc 'SELECT version();' \
    > "$BACKUP_DIR/postgresql-version.txt"

echo
echo "Generating checksums..."

(
    cd "$BACKUP_DIR"

    find . \
        -maxdepth 1 \
        -type f \
        ! -name SHA256SUMS \
        -print0 |
    sort -z |
    xargs -0 sha256sum \
        > SHA256SUMS

    sha256sum -c SHA256SUMS
)

echo
echo "Backup completed successfully:"
echo "$BACKUP_DIR"
