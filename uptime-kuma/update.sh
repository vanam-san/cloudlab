#!/usr/bin/env bash
# Update Uptime Kuma to the latest release.
# Upstream docs: https://github.com/louislam/uptime-kuma#update
# (pull the new image and recreate; the sqlite data in the volume is
# preserved and migrated automatically).
# 1. Pulls the latest image (tag from UPTIME_KUMA_IMAGE in .env).
# 2. Recreates the container (`down` + `up -d`).
# 3. Waits until the app answers on localhost again.
set -euo pipefail

cd "$(dirname "$0")"

set -a
# shellcheck disable=SC1091
source .env 2>/dev/null || true
set +a

echo "==> Pulling latest image (${UPTIME_KUMA_IMAGE:-louislam/uptime-kuma:2})"
docker compose pull

echo "==> Recreating container"
docker compose down
docker compose up -d

echo "==> Waiting for Uptime Kuma to become ready"
URL="http://localhost:${UPTIME_KUMA_PORT:-3002}"
# Accept any 2xx/3xx: `/` serves the dashboard (or setup on fresh data).
for i in $(seq 1 60); do
  CODE="$(curl -s -o /dev/null -w '%{http_code}' "$URL/" 2>/dev/null || echo 000)"
  if [[ "$CODE" =~ ^[23] ]]; then
    break
  fi
  [[ $i -eq 60 ]] && { echo "Timed out waiting for Uptime Kuma (last HTTP $CODE)"; exit 1; }
  sleep 2
done

echo ""
echo "Uptime Kuma updated and responding at $URL"
