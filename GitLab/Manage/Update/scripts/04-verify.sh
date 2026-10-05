#!/usr/bin/env bash
set -Eeuo pipefail

trap 'rc=$?; echo "[FAIL] line $LINENO: $BASH_COMMAND (exit $rc)" >&2' ERR

SCRIPT_DIR="$(
    cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1
    pwd -P
)"

COMPOSE_DIR="${COMPOSE_DIR:-/mnt/hgsc1/projects/gitlab}"
GITLAB_CONTAINER="${GITLAB_CONTAINER:-gitlab}"

cd "$COMPOSE_DIR"

echo "GitLab post-upgrade verification"
echo "================================"

docker exec "$GITLAB_CONTAINER" gitlab-rake gitlab:env:info
docker exec "$GITLAB_CONTAINER" gitlab-ctl status

echo
echo "Ordinary migrations:"
DOWN="$(docker exec "$GITLAB_CONTAINER" gitlab-rake db:migrate:status | awk '$1 == "down" {print}')"
if [[ -n "$DOWN" ]]; then
  echo "$DOWN"
  echo "[FAIL] Pending ordinary migrations." >&2
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
echo "[ OK ] Post-upgrade verification completed."
