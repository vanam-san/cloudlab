#!/usr/bin/env bash
# Stop Caddy. Certificates and config stay in the caddy-data /
# caddy-config volumes; the Caddyfile stays on disk. Start again with
# ./run.sh (or `docker compose up -d`).
# NOTE: while Caddy is stopped, all production domains are unreachable.
set -euo pipefail

cd "$(dirname "$0")"

echo "==> Stopping Caddy (certificates kept)"
docker compose down

echo "Caddy stopped."