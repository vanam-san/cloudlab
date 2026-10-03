#!/usr/bin/env bash
# Restart Uptime Kuma: recreates the container, then waits until the app
# answers on localhost again. Data in the uptime-kuma volume is untouched.
set -euo pipefail

cd "$(dirname "$0")"

set -a
# shellcheck disable=SC1091
source .env 2>/dev/null || true
set +a

echo "==> Restarting Uptime Kuma"
docker compose restart

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
echo "Uptime Kuma restarted and responding at $URL"
