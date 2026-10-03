#!/usr/bin/env bash
# Stop Checkmate: `docker compose down` removes containers and the network but
# keeps the mongo-data volume, so all monitors, history, and users survive
# the stop. Start again with ./run.sh (or `docker compose up -d`).
set -euo pipefail

cd "$(dirname "$0")"

echo "==> Stopping Checkmate (data volume kept)"
docker compose down

echo "Checkmate stopped."
