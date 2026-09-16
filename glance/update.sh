#!/usr/bin/env bash
# Update Glance to the latest release.
# Upstream: https://github.com/glanceapp/glance (image glanceapp/glance).
# 1. Pulls the latest image.
# 2. Recreates the container; the dashboard config lives in ./config
#    (bind mount, untouched by the update).
# 3. Waits until the dashboard answers on localhost again.
set -euo pipefail

cd "$(dirname "$0")"

echo "==> Pulling latest images"
docker compose pull

echo "==> Recreating Glance"
docker compose up -d

echo "==> Waiting for Glance to become ready"
# shellcheck disable=SC1091
source .env 2>/dev/null || true
URL="http://localhost:${GLANCE_PORT:-8080}"
for i in $(seq 1 60); do
  if curl -fsS -o /dev/null "$URL/" >/dev/null 2>&1; then
    break
  fi
  [[ $i -eq 60 ]] && { echo "Timed out waiting for Glance"; docker compose logs --tail 20 glance; exit 1; }
  sleep 2
done

echo ""
echo "Glance updated and responding at $URL"