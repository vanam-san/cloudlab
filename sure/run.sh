#!/usr/bin/env bash
# One-command deploy for Sure: ./run.sh
# 1. Creates .env from .env.example (git-ignored, never committed).
# 2. Generates random POSTGRES_PASSWORD / SECRET_KEY_BASE on first run
#    (upstream ships publicly known example defaults).
# 3. Pulls the Sure + Postgres + Redis images.
# 4. Starts the stack and waits until the app answers on localhost.
# After the first start, register the admin account in the web UI, then
# restrict signups under Settings > Self-Hosting > Onboarding.
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

# Random hex secret; openssl preferred, /dev/urandom as fallback
# (same two methods as upstream docs: docs/hosting/docker.md).
gen_hex() {
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -hex "$1"
  else
    head -c "$1" /dev/urandom | od -An -tx1 | tr -d ' \n'
  fi
}

if grep -q '^POSTGRES_PASSWORD=change-me' "$ENV_FILE"; then
  echo "==> Generating random POSTGRES_PASSWORD"
  sed -i "s|^POSTGRES_PASSWORD=.*|POSTGRES_PASSWORD=$(gen_hex 24)|" "$ENV_FILE"
fi

if grep -q '^SECRET_KEY_BASE=change-me' "$ENV_FILE"; then
  echo "==> Generating random SECRET_KEY_BASE"
  sed -i "s|^SECRET_KEY_BASE=.*|SECRET_KEY_BASE=$(gen_hex 64)|" "$ENV_FILE"
fi

echo "==> Pulling latest images (${SURE_IMAGE:-ghcr.io/we-promise/sure:stable})"
docker compose pull

echo "==> Starting Sure"
docker compose up -d

echo "==> Waiting for Sure to become ready"
URL="http://localhost:${PORT:-3001}"
# Accept any 2xx/3xx: `/` may redirect to the login/registration page.
for i in $(seq 1 90); do
  CODE="$(curl -s -o /dev/null -w '%{http_code}' "$URL/" 2>/dev/null || echo 000)"
  if [[ "$CODE" =~ ^[23] ]]; then
    break
  fi
  [[ $i -eq 90 ]] && { echo "Timed out waiting for Sure (last HTTP $CODE)"; exit 1; }
  sleep 2
done

echo ""
echo "Sure is up!"
echo "  URL:   $URL"
echo "  Register the admin account, then set onboarding to Invite-only"
echo "  or Closed under Settings > Self-Hosting > Onboarding."