#!/usr/bin/env bash
# Stop Sure (web + worker + db + redis). Data survives in named volumes
# (postgres-data, redis-data, app-storage). Start again with ./run.sh
# (or `docker compose up -d`).
set -euo pipefail

cd "$(dirname "$0")"

echo "==> Stopping Sure (data volumes kept)"
docker compose down

echo "Sure stopped."