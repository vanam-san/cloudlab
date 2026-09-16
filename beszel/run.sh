#!/usr/bin/env bash
# One-command deploy for Beszel hub (+ optional agent): ./run.sh
# 1. Creates .env from .env.example (git-ignored, never committed).
# 2. Pulls the Beszel hub image (and the agent image if paired).
# 3. Starts the hub and waits until it answers on localhost.
# 4. If AGENT_TOKEN/AGENT_KEY are set in .env, also starts the agent
#    service (behind the `agent` compose profile) to monitor this VPS.
# After the first start, create the admin account in the web UI, then add
# this VPS as a monitored system (see README.md), paste the tokens into
# .env and re-run this script.
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

echo "==> Pulling latest images (${BESZEL_IMAGE:-henrygd/beszel:latest})"
docker compose pull

echo "==> Starting Beszel hub"
docker compose up -d

# Start the agent too if it was paired (tokens from the .env
# already sourced above; empty = agent stays off).
if [[ -n "${AGENT_TOKEN:-}" && -n "${AGENT_KEY:-}" ]]; then
  echo "==> Agent tokens found, starting beszel-agent"
  docker compose --profile agent up -d beszel-agent
fi

echo "==> Waiting for Beszel hub to become ready"
URL="http://localhost:${BESZEL_PORT:-8090}"
# Accept any 2xx/3xx: `/` may redirect to the login/setup page.
for i in $(seq 1 60); do
  CODE="$(curl -s -o /dev/null -w '%{http_code}' "$URL/" 2>/dev/null || echo 000)"
  if [[ "$CODE" =~ ^[23] ]]; then
    break
  fi
  [[ $i -eq 60 ]] && { echo "Timed out waiting for Beszel hub (last HTTP $CODE)"; exit 1; }
  sleep 2
done

echo ""
echo "Beszel hub is up!"
echo "  URL:   $URL"
echo "  Create the admin account in the web UI, then add this VPS"
echo "  as a system (see README.md for the agent setup)."