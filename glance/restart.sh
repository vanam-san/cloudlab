#!/usr/bin/env bash
# Restart Glance (e.g. to apply config/glance.yml changes), then wait until
# the dashboard answers on localhost again. The dashboard config is a bind
# mount and is untouched by the restart.
set -euo pipefail

cd "$(dirname "$0")"

# shellcheck disable=SC1091
source .env 2>/dev/null || true

echo "==> Restarting Glance"
docker compose restart glance

echo "==> Waiting for Glance to become ready"
URL="http://localhost:${GLANCE_PORT:-8080}"
# `/` serves the dashboard with 200 once the binary has loaded the config.
for i in $(seq 1 60); do
  if curl -fsS -o /dev/null "$URL/" >/dev/null 2>&1; then
    break
  fi
  [[ $i -eq 60 ]] && { echo "Timed out waiting for Glance"; docker compose logs --tail 20 glance; exit 1; }
  sleep 2
done

echo ""
echo "Glance restarted and responding at $URL"