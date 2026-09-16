#!/usr/bin/env bash
# One-command deploy for Caddy: ./run.sh
# 1. Creates .env from .env.example (git-ignored, never committed).
# 2. Pulls the Caddy image.
# 3. Validates the Caddyfile before (re)starting, so a bad config
#    can never take down the running proxy.
# 4. Starts the stack and waits until the container reports healthy.
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

echo "==> Pulling latest images (${CADDY_IMAGE:-caddy:latest})"
docker compose pull

echo "==> Validating Caddyfile"
docker run --rm -v ./Caddyfile:/etc/caddy/Caddyfile:ro \
  "${CADDY_IMAGE:-caddy:latest}" \
  caddy validate --adapter caddyfile --config /etc/caddy/Caddyfile

echo "==> Starting Caddy"
docker compose up -d

echo "==> Waiting for Caddy to become ready"
# Readiness comes from `docker inspect`, not HTTP: the admin API that the
# healthcheck uses binds to the container's loopback and is unreachable
# from the host, and port 80 answers 404 until a site is configured.
for i in $(seq 1 30); do
  STATUS="$(docker inspect caddy --format '{{.State.Health.Status}}' 2>/dev/null || echo starting)"
  [[ "$STATUS" == "healthy" ]] && break
  if [[ $i -eq 30 ]]; then
    echo "Timed out waiting for Caddy (status: $STATUS)"
    exit 1
  fi
  sleep 2
done

echo ""
echo "Caddy is up!"
echo "  HTTP:  http://<server-ip>/ (no sites configured yet)"
echo "  Edit ./Caddyfile to add a site, then reload with:"
echo "    docker compose exec caddy caddy reload --config /etc/caddy/Caddyfile --adapter caddyfile"