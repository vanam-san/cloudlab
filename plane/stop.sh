#!/usr/bin/env bash
# Stop Plane via upstream setup.sh (`down`: containers + network removed,
# data volumes and plane-app/plane.env kept). Start again with ./run.sh
# (or `./setup.sh start`).
set -euo pipefail

cd "$(dirname "$0")"

echo "==> Stopping Plane (data + config kept)"
./setup.sh stop

echo "Plane stopped."