#!/usr/bin/env bash
# Stop Glance. The dashboard config in ./config stays on disk (bind mount),
# so nothing is lost. Start again with ./run.sh (or `docker compose up -d`).
set -euo pipefail

cd "$(dirname "$0")"

echo "==> Stopping Glance (config kept)"
docker compose down

echo "Glance stopped."