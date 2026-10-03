#!/usr/bin/env bash
# Restart Checkmate: recreates containers, then waits until the app answers
# on localhost again. Data in the mongo-data volume is untouched.
set -euo pipefail

cd "$(dirname "$0")"

set -a
# shellcheck disable=SC1091
source .env 2>/dev/null || true
set +a

echo "==> Restarting Checkmate"
docker compose restart

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
echo "Checkmate restarted and responding at $URL"
