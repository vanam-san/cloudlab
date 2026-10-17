#!/usr/bin/env bash
# One-command deploy for Caddy: ./run.sh
# 1. Creates .env from .env.example (git-ignored, never committed).
# 2. Creates basic-auth.caddy from its .example with a strong random
#    password (printed once) — the default browser-access gate.
# 3. Creates tailscale-ips.caddy from its .example (git-ignored).
# 4. Pulls the Caddy image.
# 5. Validates the Caddyfile before (re)starting, so a bad config
#    can never take down the running proxy.
# 6. Starts the stack and waits until the container reports healthy.
set -euo pipefail

cd "$(dirname "$0")"

ENV_FILE=".env"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "==> Creating $ENV_FILE from .env.example"
  cp .env.example "$ENV_FILE"
fi

if [[ ! -f "tailscale-ips.caddy" ]]; then
  echo "==> Creating tailscale-ips.caddy from tailscale-ips.caddy.example"
  echo "    Only needed if you opt into `import tailscale-only` on a site."
  cp tailscale-ips.caddy.example tailscale-ips.caddy
fi

# Load .env for the values read below. Defaults apply when keys are
# missing (e.g. a .env created before those keys existed).
# shellcheck disable=SC1091
source "$ENV_FILE" 2>/dev/null || true

echo "==> Ensuring shared proxy network (cloudlab-proxy)"
docker network inspect cloudlab-proxy >/dev/null 2>&1 || docker network create cloudlab-proxy

echo "==> Pulling latest images (${CADDY_IMAGE:-caddy:latest})"
docker compose pull

# Default browser-access gate: HTTP Basic Auth on every site. Generate
# the live snippet (git-ignored) with a strong random password, stored
# as a plain username/password pair. Printed once — store it now.
if [[ ! -f "basic-auth.caddy" ]]; then
  echo "==> Creating basic-auth.caddy (Basic Auth credentials)"
  BASIC_AUTH_USER="${BASIC_AUTH_USER:-admin}"
  BASIC_AUTH_PASSWORD="$(openssl rand -base64 32 | tr -dc 'A-Za-z0-9' | head -c 24)"
  BASIC_AUTH_PASSWORD_BASE64="$(printf '%s' "$BASIC_AUTH_PASSWORD" | base64 -w0)"
  sed -e "s/__BASIC_AUTH_USER__/${BASIC_AUTH_USER}/" \
      -e "s|__BASIC_AUTH_PASSWORD_BASE64__|${BASIC_AUTH_PASSWORD_BASE64}|" \
      basic-auth.caddy.example > basic-auth.caddy
  echo "    User:     ${BASIC_AUTH_USER}"
  echo "    Password: ${BASIC_AUTH_PASSWORD}   (shown once — store it now)"
fi

echo "==> Validating Caddyfile"
# All three files are mounted because the Caddyfile imports both snippets.
docker run --rm -v ./Caddyfile:/etc/caddy/Caddyfile:ro \
  -v ./basic-auth.caddy:/etc/caddy/basic-auth.caddy:ro \
  -v ./tailscale-ips.caddy:/etc/caddy/tailscale-ips.caddy:ro \
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
echo "  No sites configured yet — the default-deny block drops direct-IP"
echo "  connections (by design). Edit ./Caddyfile to add a site, then reload with:"
echo "    docker compose exec caddy caddy reload --config /etc/caddy/Caddyfile --adapter caddyfile"