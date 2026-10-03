#!/usr/bin/env bash
# Update Checkmk to the latest release.
# Upstream docs: https://docs.checkmk.com/latest/en/update_major.html
# (containers: pull the new image and recreate; the entrypoint updates
# the site automatically — back up first, see README.md).
# 1. Pulls the latest image (tag from CHECKMK_IMAGE in .env).
# 2. Recreates the container (`down` + `up -d`); data in the checkmk
#    volume is preserved and the site migrates on startup.
# 3. Waits until the web UI answers on localhost again.
set -euo pipefail

cd "$(dirname "$0")"

set -a
# shellcheck disable=SC1091
source .env 2>/dev/null || true
set +a

echo "==> Pulling latest image (${CHECKMK_IMAGE:-checkmk/check-mk-raw:2.4.0-latest})"
docker compose pull

echo "==> Recreating container (site migrates on boot)"
docker compose down
docker compose up -d

echo "==> Waiting for Checkmk web UI to become ready"
SITE="${CMK_SITE_ID:-cmk}"
URL="http://localhost:${CHECKMK_PORT:-8072}"
# Accept any 2xx/3xx: the site path redirects to the login page.
for i in $(seq 1 90); do
  CODE="$(curl -s -o /dev/null -w '%{http_code}' "$URL/$SITE/" 2>/dev/null || echo 000)"
  if [[ "$CODE" =~ ^[23] ]]; then
    break
  fi
  [[ $i -eq 90 ]] && { echo "Timed out waiting for Checkmk (last HTTP $CODE)"; exit 1; }
  sleep 5
done

echo ""
echo "Checkmk updated and responding at $URL/$SITE/"
