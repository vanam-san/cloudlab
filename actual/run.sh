#!/usr/bin/env bash
# One-command deploy for Actual Budget: ./run.sh
# 1. Creates .env from .env.example (git-ignored, never committed).
# 2. Pulls the Actual Budget server image.
# 3. Starts the server on localhost:5006 and waits until it answers.
# On first run, open the URL and set the server password in the UI.
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
# shellcheck disable=SC1091
source "$ENV_FILE" 2>/dev/null || true

echo "==> Ensuring shared proxy network (cloudlab-proxy)"
docker network inspect cloudlab-proxy >/dev/null 2>&1 || docker network create cloudlab-proxy

echo "==> Pulling latest images (${ACTUAL_IMAGE:-actualbudget/actual-server:latest})"
docker compose pull

echo "==> Starting Actual Budget"
docker compose up -d

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
echo "Actual Budget is up!"
echo "  URL:   $URL"
echo "  Set the server password in the UI on first run."
