#!/usr/bin/env bash
# Restart Checkmk: recreates the container, then waits until the web UI
# answers on localhost again. Data in the checkmk volume is untouched.
set -euo pipefail

cd "$(dirname "$0")"

set -a
# shellcheck disable=SC1091
source .env 2>/dev/null || true
set +a

echo "==> Restarting Checkmk"
docker compose restart

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
echo "Checkmk restarted and responding at $URL/$SITE/"
