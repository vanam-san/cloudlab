#!/usr/bin/env bash
# Stop Beszel hub + agent. The `--profile agent` flag matters: without it,
# `down` would leave a running agent container behind.
# Data and pairing survive in named volumes. Start again with ./run.sh.
set -euo pipefail

cd "$(dirname "$0")"

echo "==> Stopping Beszel (data + pairing kept)"
docker compose --profile agent down

echo "Beszel stopped."