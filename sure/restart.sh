#!/usr/bin/env bash
# Restart Sure (web + worker + db + redis), then wait until the app answers
# on localhost again. Data in named volumes is untouched.
set -euo pipefail

cd "$(dirname "$0")"

# shellcheck disable=SC1091
source .env 2>/dev/null || true

echo "==> Restarting Sure"
docker compose restart

echo "==> Waiting for Sure to become ready"
URL="http://localhost:${PORT:-3001}"
# Accept any 2xx/3xx: `/` may redirect to the login/registration page.
for i in $(seq 1 90); do
  CODE="$(curl -s -o /dev/null -w '%{http_code}' "$URL/" 2>/dev/null || echo 000)"
  if [[ "$CODE" =~ ^[23] ]]; then
    break
  fi
  [[ $i -eq 90 ]] && { echo "Timed out waiting for Sure (last HTTP $CODE)"; exit 1; }
  sleep 2
done

echo ""
echo "Sure restarted and responding at $URL"