#!/usr/bin/env bash
# One-command deploy for Umami: ./run.sh
# 1. Creates .env from .env.example (git-ignored, never committed).
# 2. Generates a random APP_SECRET (required to secure auth tokens).
# 3. Pulls the Umami + Postgres images.
# 4. Starts the stack and waits until the app answers on localhost.
set -euo pipefail

cd "$(dirname "$0")"

ENV_FILE=".env"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "==> Creating $ENV_FILE from .env.example"
  cp .env.example "$ENV_FILE"
fi

# Load .env for the values read below. Defaults apply when keys are
# missing (e.g. a .env created before those keys existed).
# shellcheck disable=SC1091
source "$ENV_FILE" 2>/dev/null || true

echo "==> Ensuring shared proxy network (cloudlab-proxy)"
docker network inspect cloudlab-proxy >/dev/null 2>&1 || docker network create cloudlab-proxy

if grep -q '^APP_SECRET=change-me\|^APP_SECRET=$' "$ENV_FILE" || ! grep -q '^APP_SECRET=.' "$ENV_FILE"; then
  if command -v openssl >/dev/null 2>&1; then
    SECRET="$(openssl rand -hex 32)"
  else
    SECRET="$(head -c 64 /dev/urandom | od -An -tx1 | tr -d ' \n')"
  fi
  echo "==> Generating random APP_SECRET"
  sed -i "s|^APP_SECRET=.*|APP_SECRET=$SECRET|" "$ENV_FILE"
fi

echo "==> Pulling latest images (${UMAMI_IMAGE:-docker.umami.is/umami-software/umami:latest})"
docker compose pull

echo "==> Starting Umami"
docker compose up -d

echo "==> Waiting for Umami to become ready"
URL="http://localhost:${UMAMI_PORT:-3000}"
# Poll `/` (not /api/health): this build has no /api/health route (404),
# while `/` returns 200 once Next.js is serving.
for i in $(seq 1 60); do
  if curl -fsS -o /dev/null "$URL/" >/dev/null 2>&1; then
    break
  fi
  [[ $i -eq 60 ]] && { echo "Timed out waiting for Umami"; exit 1; }
  sleep 2
done

echo ""
echo "Umami is up!"
echo "  URL:        $URL"
echo "  Login:      admin / umami"
echo "  Change the default password after first login."