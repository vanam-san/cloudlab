#!/usr/bin/env bash
# One-command deploy for Plane (community edition): ./run.sh
# Wraps upstream setup.sh (committed copy with one commented compat fix
# for compact GitHub API JSON). Flow:
# 1. Creates .env from .env.example (only our port/domain overrides).
# 2. Runs `./setup.sh install` on first run only. Its pull step fails on
#    the retired `minio/minio` Docker Hub repo — tolerated, because the
#    compose + env files are written before that step.
# 3. Points plane-app/plane.env at localhost (ports, WEB_URL, CORS) and
#    generates the two "change before deploying" secrets on first run.
# 4. Binds Plane's proxy ports to 127.0.0.1 (localhost-only like every
#    other service here; re-applied because upgrades re-download compose).
# 5. Provides the minio image from Quay (same version line as upstream).
# 6. Starts via `./setup.sh start` (itself waits for DB migrations).
# 7. Waits until the app answers 200 on localhost (first boot runs
#    migrations and pulls ~10 images, so this can take several minutes).
set -euo pipefail

cd "$(dirname "$0")"

ENV_FILE=".env"
SETUP="./setup.sh"
APP_DIR="plane-app"
COMPOSE="$APP_DIR/docker-compose.yaml"
PLANE_ENV="$APP_DIR/plane.env"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "==> Creating $ENV_FILE from .env.example"
  cp .env.example "$ENV_FILE"
fi

# Load our overrides (defaults apply if keys are missing).
# shellcheck disable=SC1091
source "$ENV_FILE" 2>/dev/null || true
PLANE_PORT="${PLANE_PORT:-8088}"
PLANE_HTTPS_PORT="${PLANE_HTTPS_PORT:-9443}"
PLANE_APP_DOMAIN="${PLANE_APP_DOMAIN:-localhost}"
PLANE_WEB_URL="${PLANE_WEB_URL:-http://localhost:$PLANE_PORT}"
PLANE_CORS_ORIGINS="${PLANE_CORS_ORIGINS:-http://localhost:$PLANE_PORT}"

if [[ ! -f "$SETUP" ]]; then
  echo "==> Downloading upstream setup.sh"
  curl -fsSL -o "$SETUP" https://github.com/makeplane/plane/releases/latest/download/setup.sh
  chmod +x "$SETUP"
fi

if [[ ! -f "$COMPOSE" ]]; then
  echo "==> First install via upstream setup.sh"
  # Tolerates setup.sh exiting 1 on the dead minio repo: compose + env
  # files are written before its pull step.
  "$SETUP" install || true
  [[ -f "$COMPOSE" && -f "$PLANE_ENV" ]] || { echo "Install failed: $COMPOSE missing"; exit 1; }
fi

# --- localhost/production settings in plane.env (idempotent) ---
set_kv() { # set_kv FILE KEY VALUE — replace or append
  if grep -q "^$2=" "$1"; then
    sed -i "s|^$2=.*|$2=$3|" "$1"
  else
    printf '%s=%s\n' "$2" "$3" >> "$1"
  fi
}
set_kv "$PLANE_ENV" LISTEN_HTTP_PORT "$PLANE_PORT"
set_kv "$PLANE_ENV" LISTEN_HTTPS_PORT "$PLANE_HTTPS_PORT"
set_kv "$PLANE_ENV" APP_DOMAIN "$PLANE_APP_DOMAIN"
set_kv "$PLANE_ENV" WEB_URL "$PLANE_WEB_URL"
set_kv "$PLANE_ENV" CORS_ALLOWED_ORIGINS "$PLANE_CORS_ORIGINS"

# Generate the two secrets upstream flags "change before deploying",
# but only while still at their documented defaults.
if grep -q '^SECRET_KEY=change-this-key-on-deployment' "$PLANE_ENV"; then
  echo "==> Generating SECRET_KEY"
  sed -i "s|^SECRET_KEY=.*|SECRET_KEY=$(openssl rand -hex 32)|" "$PLANE_ENV"
fi
if grep -q '^LIVE_SERVER_SECRET_KEY=change-this-key-on-deployment' "$PLANE_ENV"; then
  echo "==> Generating LIVE_SERVER_SECRET_KEY"
  sed -i "s|^LIVE_SERVER_SECRET_KEY=.*|LIVE_SERVER_SECRET_KEY=$(openssl rand -hex 32)|" "$PLANE_ENV"
fi

# --- localhost-only proxy bind (upgrades re-download compose, re-apply) ---
if ! grep -q "host_ip: 127.0.0.1" "$COMPOSE"; then
  echo "==> Binding Plane proxy to 127.0.0.1"
  python3 - "$COMPOSE" <<'EOF'
import sys
p = sys.argv[1]
out = []
for l in open(p).read().split('\n'):
    out.append(l)
    # insert AFTER the complete published: line (same indent)
    if 'published: ${LISTEN_' in l and l.rstrip().endswith('}'):
        out.append(l[:len(l) - len(l.lstrip())] + 'host_ip: 127.0.0.1')
open(p, 'w').write('\n'.join(out))
EOF
fi

# --- minio workaround: Docker Hub repo retired, MinIO ships via Quay ---
if ! docker image inspect minio/minio:latest >/dev/null 2>&1; then
  echo "==> Providing minio image from Quay (Docker Hub repo retired)"
  docker pull quay.io/minio/minio:latest
  docker tag quay.io/minio/minio:latest minio/minio:latest
fi

echo "==> Starting Plane (setup.sh waits for DB migrations)"
"$SETUP" start

echo "==> Waiting for Plane to answer"
URL="http://localhost:$PLANE_PORT"
for i in $(seq 1 180); do
  if curl -fsS -o /dev/null "$URL/" >/dev/null 2>&1; then
    break
  fi
  [[ $i -eq 180 ]] && { echo "Timed out waiting for Plane"; exit 1; }
  sleep 5
done

echo ""
echo "Plane is up!"
echo "  URL:   $URL"
echo "  Create the admin account in the web UI on first visit."