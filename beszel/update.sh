#!/usr/bin/env bash
# Update Beszel hub (+ agent if paired) to the latest release.
# Upstream: https://beszel.dev/ (Docker images henrygd/beszel,
# henrygd/beszel-agent; releases at github.com/henrygd/beszel/releases).
# 1. Pulls the latest image(s).
# 2. Recreates the container(s); hub data, agent state and the pairing
#    survive in named volumes, so no re-pairing is needed.
# 3. Waits until the hub answers on localhost again.
set -euo pipefail

cd "$(dirname "$0")"

echo "==> Pulling latest images"
docker compose pull

echo "==> Recreating Beszel hub"
docker compose up -d

# shellcheck disable=SC1091
source .env 2>/dev/null || true
if [[ -n "${AGENT_TOKEN:-}" && -n "${AGENT_KEY:-}" ]]; then
  echo "==> Recreating beszel-agent"
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
echo "Beszel updated and responding at $URL"