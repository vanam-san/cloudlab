#!/usr/bin/env bash
# Stop Uptime Kuma: `docker compose down` removes the container and the
# network but keeps the uptime-kuma volume, so all monitors, history, and
# users survive the stop. Start again with ./run.sh
# (or `docker compose up -d`).
set -euo pipefail

cd "$(dirname "$0")"

echo "==> Stopping Uptime Kuma (data volume kept)"
docker compose down

echo "Uptime Kuma stopped."
