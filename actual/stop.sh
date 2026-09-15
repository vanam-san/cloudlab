#!/usr/bin/env bash
# Stop Actual Budget. Data survives in the named volume (actual-data).
# Start again with ./run.sh (or `docker compose up -d`).
set -euo pipefail

cd "$(dirname "$0")"

echo "==> Stopping Actual Budget (data volume kept)"
docker compose down

echo "Actual Budget stopped."
