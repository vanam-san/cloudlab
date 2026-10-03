#!/usr/bin/env bash
# One-command deploy for Uptime Kuma: ./run.sh
# 1. Creates .env from .env.example (git-ignored, never committed).
# 2. Pulls the Uptime Kuma image.
# 3. Starts the stack and waits until the app answers on localhost.
# After the first start, create the admin account in the web UI.
# It is idempotent — safe to re-run any time.
set -euo pipefail

cd "$(dirname "$0")"

ENV_FILE=".env"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "==> Creating $ENV_FILE from .env.example"
  cp .env.example "$ENV_FILE"
fi

# Load .env for the values read below. Defaults apply when keys are
# missing (e.g. a .env created before those keys existed).
set -a
# shellcheck disable=SC1091
source "$ENV_FILE" 2>/dev/null || true
set +a

echo "==> Ensuring shared proxy network (cloudlab-proxy)"
docker network inspect cloudlab-proxy >/dev/null 2>&1 || docker network create cloudlab-proxy

echo "==> Pulling latest image (${UPTIME_KUMA_IMAGE:-louislam/uptime-kuma:2})"
docker compose pull

echo "==> Starting Uptime Kuma"
docker compose up -d

echo "==> Waiting for Uptime Kuma to become ready"
URL="http://localhost:${UPTIME_KUMA_PORT:-3002}"
# Accept any 2xx/3xx: `/` serves the setup page first, then the dashboard.
for i in $(seq 1 60); do
  CODE="$(curl -s -o /dev/null -w '%{http_code}' "$URL/" 2>/dev/null || echo 000)"
  if [[ "$CODE" =~ ^[23] ]]; then
    break
  fi
  [[ $i -eq 60 ]] && { echo "Timed out waiting for Uptime Kuma (last HTTP $CODE)"; exit 1; }
  sleep 2
done

echo ""
echo "Uptime Kuma is up!"
echo "  URL:   $URL"
echo "  Create the admin account in the web UI on first visit."
