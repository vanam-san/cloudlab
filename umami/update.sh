#!/usr/bin/env bash
# Update Umami to the latest release.
# Upstream docs: https://umami.is/docs/updates ("Docker").
# 1. Pulls the latest image (docker.umami.is/.../umami:latest).
# 2. Recreates containers (`down` + `up -d`, as the docs prescribe); data
#    in the umami-db volume is preserved and DB migrations run
#    automatically on startup.
# 3. Waits until the app answers on localhost again.
# Note: after MAJOR upgrades, refresh Postgres planner statistics
# (see "Updating" in README.md).
set -euo pipefail

cd "$(dirname "$0")"

echo "==> Pulling latest images"
docker compose pull

echo "==> Recreating containers"
docker compose down
docker compose up -d

echo "==> Waiting for Umami to become ready"
# shellcheck disable=SC1091
source .env 2>/dev/null || true
URL="http://localhost:${UMAMI_PORT:-3000}"
# Poll `/` (not /api/health): this build has no /api/health route (404),
# while `/` returns 200 once Next.js is serving.
for i in $(seq 1 60); do
  if curl -fsS -o /dev/null "$URL/" >/dev/null 2>&1; then
    break
  fi
  [[ $i -eq 60 ]] && { echo "Timed out waiting for Umami"; exit 1; }
  sleep 2
done

echo ""
echo "Umami updated and responding at $URL"