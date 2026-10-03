#!/usr/bin/env bash
# Update Checkmate to the latest release.
# Upstream: pull the new image and recreate (data in the mongo-data volume
# is preserved). No migration step for the all-in-one image.
# 1. Pulls the latest images (tags from .env).
# 2. Recreates containers (`down` + `up -d`).
# 3. Waits until the app answers on localhost again.
set -euo pipefail

cd "$(dirname "$0")"

set -a
# shellcheck disable=SC1091
source .env 2>/dev/null || true
set +a

echo "==> Pulling latest images (${CHECKMATE_IMAGE:-ghcr.io/bluewave-labs/checkmate:latest})"
docker compose pull

echo "==> Recreating containers"
docker compose down
docker compose up -d

echo "==> Waiting for Checkmate to become ready"
URL="http://localhost:${CHECKMATE_PORT:-8073}"
# Accept any 2xx/3xx: `/` serves the app (login page once set up).
for i in $(seq 1 60); do
  CODE="$(curl -s -o /dev/null -w '%{http_code}' "$URL/" 2>/dev/null || echo 000)"
  if [[ "$CODE" =~ ^[23] ]]; then
    break
  fi
  [[ $i -eq 60 ]] && { echo "Timed out waiting for Checkmate (last HTTP $CODE)"; exit 1; }
  sleep 2
done

echo ""
echo "Checkmate updated and responding at $URL"
