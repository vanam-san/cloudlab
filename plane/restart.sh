#!/usr/bin/env bash
# Restart Plane via upstream setup.sh (stop + start, non-interactive),
# then wait until the app answers on localhost again.
# Data in Docker volumes and plane-app/plane.env are untouched.
set -euo pipefail

cd "$(dirname "$0")"

# shellcheck disable=SC1091
source .env 2>/dev/null || true

echo "==> Restarting Plane"
./setup.sh restart

echo "==> Waiting for Plane to become ready"
URL="http://localhost:${PLANE_PORT:-9080}"
for i in $(seq 1 120); do
  if curl -fsS -o /dev/null "$URL/" >/dev/null 2>&1; then
    break
  fi
  [[ $i -eq 120 ]] && { echo "Timed out waiting for Plane"; exit 1; }
  sleep 5
done

echo ""
echo "Plane restarted and responding at $URL"