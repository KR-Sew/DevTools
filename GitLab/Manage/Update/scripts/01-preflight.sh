#!/usr/bin/env bash
set -Eeuo pipefail

trap 'rc=$?; echo "[FAIL] line $LINENO: $BASH_COMMAND (exit $rc)" >&2' ERR

SCRIPT_DIR="$(
    cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1
    pwd -P
)"

COMPOSE_DIR="${COMPOSE_DIR:-/mnt/hgsc1/projects/gitlab}"
GITLAB_CONTAINER="${GITLAB_CONTAINER:-gitlab}"
POSTGRES_CONTAINER="${POSTGRES_CONTAINER:-gitlab_postgres}"

cd "$COMPOSE_DIR"

echo "GitLab upgrade preflight"
echo "========================"

docker compose config --quiet
docker inspect "$GITLAB_CONTAINER" >/dev/null
docker inspect "$POSTGRES_CONTAINER" >/dev/null

GITLAB_VERSION="$(docker exec "$GITLAB_CONTAINER" gitlab-rails runner 'puts Gitlab::VERSION')"
GITLAB_VERSION="${GITLAB_VERSION//$'\r'/}"

PG_DB="$(docker inspect "$POSTGRES_CONTAINER" --format '{{range .Config.Env}}{{println .}}{{end}}' | sed -n 's/^POSTGRES_DB=//p')"
PG_USER="$(docker inspect "$POSTGRES_CONTAINER" --format '{{range .Config.Env}}{{println .}}{{end}}' | sed -n 's/^POSTGRES_USER=//p')"

echo "[ OK ] GitLab version: $GITLAB_VERSION"
docker exec "$POSTGRES_CONTAINER" psql -U "$PG_USER" -d "$PG_DB" -Atc \
  "SELECT 'PostgreSQL ' || current_setting('server_version');"

echo
echo "Disk space:"
df -hT /mnt/hgsc1 /mnt/hgsd1

echo
echo "PostgreSQL readiness:"
docker exec "$POSTGRES_CONTAINER" pg_isready -U "$PG_USER" -d "$PG_DB"

echo
echo "GitLab services:"
docker exec "$GITLAB_CONTAINER" gitlab-ctl status

echo
echo "Ordinary migrations (no output is expected):"
DOWN="$(docker exec "$GITLAB_CONTAINER" gitlab-rake db:migrate:status | awk '$1 == "down" {print}')"
if [[ -n "$DOWN" ]]; then
  echo "$DOWN"
  echo "[FAIL] Ordinary migrations are pending." >&2
  exit 1
fi
echo "[ OK ] All ordinary migrations are up."

echo
echo "Batched background migrations:"
docker exec "$GITLAB_CONTAINER" gitlab-rails runner '
model = Gitlab::Database::BackgroundMigration::BatchedMigration
bad = model.where.not(status: [:finished, :finalized])
puts "Incomplete migrations: #{bad.count}"
bad.order(:id).find_each do |m|
  puts "id=#{m.id} class=#{m.job_class_name} status=#{m.status}"
end
exit 1 if bad.exists?
'

echo
echo "GitLab health:"
docker exec "$GITLAB_CONTAINER" gitlab-rake gitlab:check SANITIZE=true

echo
echo "[ OK ] Preflight completed."
