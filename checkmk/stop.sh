#!/usr/bin/env bash
# Stop Checkmk: `docker compose down` removes the container and the network
# but keeps the checkmk volume, so the whole site (hosts, history,
# configuration) survives the stop. Start again with ./run.sh
# (or `docker compose up -d`).
set -euo pipefail

cd "$(dirname "$0")"

echo "==> Stopping Checkmk (site volume kept)"
docker compose down

echo "Checkmk stopped."
