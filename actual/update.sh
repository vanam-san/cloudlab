#!/usr/bin/env bash
# Update Actual Budget to the latest release.
# Upstream docs: https://actualbudget.org/docs/install/docker
# ("Update Docker Compose container").
# 1. Pulls the latest image (tag from ACTUAL_IMAGE in .env).
# 2. Recreates the container (`down` + `up -d`, as the docs prescribe);
#    data in the actual-data volume is preserved.
# 3. Waits until the app answers on localhost again.
set -euo pipefail

cd "$(dirname "$0")"

echo "==> Pulling latest images"
docker compose pull

echo "==> Recreating containers"
docker compose down
docker compose up -d

echo "==> Waiting for Actual Budget to become ready"
# shellcheck disable=SC1091
source .env 2>/dev/null || true
URL="http://localhost:${ACTUAL_PORT:-5006}"
# `/` serves the web UI with 200 once the server is up.
for i in $(seq 1 60); do
  if curl -fsS -o /dev/null "$URL/" >/dev/null 2>&1; then
    break
  fi
  [[ $i -eq 60 ]] && { echo "Timed out waiting for Actual Budget"; docker compose logs --tail 20 actual; exit 1; }
  sleep 2
done

echo ""
echo "Actual Budget updated and responding at $URL"
