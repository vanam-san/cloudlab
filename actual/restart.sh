#!/usr/bin/env bash
# Restart Actual Budget, then wait until the app answers on localhost
# again. Data in the named volume is untouched.
set -euo pipefail

cd "$(dirname "$0")"

# shellcheck disable=SC1091
source .env 2>/dev/null || true

echo "==> Restarting Actual Budget"
docker compose restart

echo "==> Waiting for Actual Budget to become ready"
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
echo "Actual Budget restarted and responding at $URL"
