#!/usr/bin/env bash
# Update Sure to the latest release.
# Upstream docs: https://github.com/we-promise/sure/blob/main/docs/hosting/docker.md
# ("How to update your app").
# 1. Pulls the latest image from GHCR (tag from SURE_IMAGE in .env).
# 2. Restarts web + worker WITHOUT touching db/redis (--no-deps), so the
#    database is never interrupted. Rails migrations run on boot.
# 3. Waits until the app answers on localhost again.
set -euo pipefail

cd "$(dirname "$0")"

echo "==> Pulling latest images"
docker compose pull

echo "==> Restarting web + worker (db/redis untouched)"
docker compose up --no-deps -d web worker

echo "==> Waiting for Sure to become ready"
# shellcheck disable=SC1091
source .env 2>/dev/null || true
URL="http://localhost:${PORT:-3001}"
# Accept any 2xx/3xx: `/` may redirect to the login page.
for i in $(seq 1 90); do
  CODE="$(curl -s -o /dev/null -w '%{http_code}' "$URL/" 2>/dev/null || echo 000)"
  if [[ "$CODE" =~ ^[23] ]]; then
    break
  fi
  [[ $i -eq 90 ]] && { echo "Timed out waiting for Sure (last HTTP $CODE)"; exit 1; }
  sleep 2
done

echo ""
echo "Sure updated and responding at $URL"