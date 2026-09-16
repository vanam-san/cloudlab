#!/usr/bin/env bash
# Update Caddy to the latest release.
# Upstream docs: https://caddyserver.com/docs/install (Docker image).
# 1. Pulls the latest image (caddy:latest).
# 2. Recreates the container; certificates and config live in the
#    caddy-data / caddy-config volumes and the mounted Caddyfile, so
#    nothing is lost and no re-issuance happens.
# 3. Waits until the container reports healthy again.
set -euo pipefail

cd "$(dirname "$0")"

echo "==> Pulling latest images"
docker compose pull

echo "==> Recreating Caddy"
docker compose up -d

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
echo "Caddy updated and healthy"