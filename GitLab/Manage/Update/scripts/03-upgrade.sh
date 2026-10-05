#!/usr/bin/env bash
set -Eeuo pipefail

trap 'rc=$?; echo "[FAIL] line $LINENO: $BASH_COMMAND (exit $rc)" >&2' ERR

# Resolve the directory where this script itself is located.
SCRIPT_DIR="$(
    cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1
    pwd -P
)"

COMPOSE_DIR="${COMPOSE_DIR:-/mnt/hgsc1/projects/gitlab}"
GITLAB_CONTAINER="${GITLAB_CONTAINER:-gitlab}"

TARGET="${1:-}"
if [[ -z "$TARGET" ]]; then
  echo "Usage: $0 <version-ce.0>" >&2
  echo "Example: $0 19.2.7-ce.0" >&2
  exit 2
fi

if [[ ! "$TARGET" =~ ^[0-9]+\.[0-9]+\.[0-9]+-ce\.0$ ]]; then
  echo "[FAIL] Invalid CE version tag: $TARGET" >&2
  exit 2
fi

cd "$COMPOSE_DIR"

CURRENT="$(docker inspect "$GITLAB_CONTAINER" --format '{{.Config.Image}}')"
echo "Current: $CURRENT"
echo "Target : gitlab/gitlab-ce:$TARGET"
echo

"$SCRIPT_DIR/01-preflight.sh"

echo
echo "[INFO] Updating pinned GitLab image in docker-compose.yml..."
cp -a docker-compose.yml "docker-compose.yml.pre-$TARGET"

python3 - "$TARGET" <<'PY'
from pathlib import Path
import re, sys
target = sys.argv[1]
p = Path("docker-compose.yml")
s = p.read_text()
new, n = re.subn(
    r'(?m)^(\s*image:\s*)gitlab/gitlab-ce:[^\s#]+',
    rf'\1gitlab/gitlab-ce:{target}',
    s,
    count=1,
)
if n != 1:
    raise SystemExit("Could not uniquely replace GitLab image tag")
p.write_text(new)
PY

docker compose config --quiet

echo "[INFO] Pulling target image..."
docker compose pull gitlab

echo "[INFO] Recreating GitLab only; PostgreSQL is left untouched..."
docker compose up -d --no-deps gitlab

echo
echo "[INFO] Waiting for GitLab container health..."
for i in $(seq 1 120); do
  STATUS="$(docker inspect gitlab --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}')"
  printf '\r[%3d/120] %s' "$i" "$STATUS"
  if [[ "$STATUS" == "healthy" ]]; then
    echo
    echo "[ OK ] GitLab is healthy."
    exit 0
  fi
  if [[ "$STATUS" == "unhealthy" || "$STATUS" == "exited" || "$STATUS" == "dead" ]]; then
    echo
    docker compose logs --tail=200 gitlab
    exit 1
  fi
  sleep 5
done

echo
echo "[FAIL] Timed out waiting for GitLab health." >&2
docker compose logs --tail=200 gitlab
exit 1
