#!/usr/bin/env bash
# Restart Caddy, then wait until the container reports healthy again.
# Certificates, config and the Caddyfile are untouched (volumes + bind
# mount), so there is no re-issuance. To apply Caddyfile edits WITHOUT a
# restart, use `docker compose exec caddy caddy reload` instead.
set -euo pipefail

cd "$(dirname "$0")"

echo "==> Restarting Caddy"
docker compose restart caddy

echo "==> Waiting for Caddy to become ready"
# Readiness comes from `docker inspect`, not HTTP (see run.sh comments).
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
echo "Caddy restarted and healthy"