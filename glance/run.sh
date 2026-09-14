#!/usr/bin/env bash
# One-command deploy for Glance: ./run.sh
# 1. Creates .env from .env.example (git-ignored, never committed).
# 2. Pulls the Glance image.
# 3. Starts the dashboard on localhost:8080 and waits until it answers.
# Customize the dashboard in config/glance.yml (committed to git), then
# apply with: docker compose restart glance
set -euo pipefail

cd "$(dirname "$0")"

ENV_FILE=".env"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "==> Creating $ENV_FILE from .env.example"
  cp .env.example "$ENV_FILE"
fi

# Load .env for the image name / port below. Defaults apply when keys are
# missing (e.g. a pre-existing .env from a manual install).
# shellcheck disable=SC1091
source "$ENV_FILE" 2>/dev/null || true

echo "==> Ensuring shared proxy network (cloudlab-proxy)"
docker network inspect cloudlab-proxy >/dev/null 2>&1 || docker network create cloudlab-proxy

echo "==> Pulling latest images (${GLANCE_IMAGE:-glanceapp/glance:latest})"
docker compose pull

echo "==> Starting Glance"
docker compose up -d

echo "==> Waiting for Glance to become ready"
URL="http://localhost:${GLANCE_PORT:-8080}"
# `/` serves the dashboard with 200 once the binary has loaded the config.
# A broken config exits the container instead - check `docker compose logs`.
for i in $(seq 1 60); do
  if curl -fsS -o /dev/null "$URL/" >/dev/null 2>&1; then
    break
  fi
  [[ $i -eq 60 ]] && { echo "Timed out waiting for Glance"; docker compose logs --tail 20 glance; exit 1; }
  sleep 2
done

echo ""
echo "Glance is up!"
echo "  URL:   $URL"