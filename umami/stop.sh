#!/usr/bin/env bash
# Stop Umami: `docker compose down` removes containers and the network but
# keeps the umami-db volume, so all analytics data survives the stop.
# Start again with ./run.sh (or `docker compose up -d`).
set -euo pipefail

cd "$(dirname "$0")"

echo "==> Stopping Umami (data volume kept)"
docker compose down

echo "Umami stopped."