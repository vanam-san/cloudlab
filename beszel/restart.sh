#!/usr/bin/env bash
# Restart Beszel hub (and the agent if paired), then wait until the hub
# answers on localhost again. Data and pairing survive in named volumes.
set -euo pipefail

cd "$(dirname "$0")"

# shellcheck disable=SC1091
source .env 2>/dev/null || true

echo "==> Restarting Beszel hub"
docker compose restart beszel

# The agent lives behind the `agent` compose profile: restart it too, but
# only if its container exists (i.e. it was paired and started before).
if docker compose --profile agent ps -a beszel-agent 2>/dev/null | grep -q beszel-agent; then
  echo "==> Restarting beszel-agent"
  docker compose --profile agent restart beszel-agent
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
echo "Beszel restarted and responding at $URL"