#!/usr/bin/env bash
# One-command deploy for Umami: ./run.sh
# 1. Creates .env from .env.example (git-ignored, never committed).
# 2. Offers to generate strong random secrets (APP_SECRET, and on fresh
#    installs POSTGRES_PASSWORD). Simple installs keep the defaults.
# 3. Pulls the Umami + Postgres images.
# 4. Starts the stack and waits until the app answers on localhost.
set -euo pipefail

cd "$(dirname "$0")"

ENV_FILE=".env"
FRESH_ENV=0

if [[ ! -f "$ENV_FILE" ]]; then
  echo "==> Creating $ENV_FILE from .env.example"
  cp .env.example "$ENV_FILE"
  FRESH_ENV=1
fi

# Load .env for the values read below. Defaults apply when keys are
# missing (e.g. a .env created before those keys existed).
# shellcheck disable=SC1091
source "$ENV_FILE" 2>/dev/null || true

echo "==> Ensuring shared proxy network (cloudlab-proxy)"
docker network inspect cloudlab-proxy >/dev/null 2>&1 || docker network create cloudlab-proxy

# Simple install by default: keep the template defaults. Opt in to strong
# random secrets with GENERATE_SECRETS=yes, or answer the prompt below.
# Non-interactive runs keep the defaults (GENERATE_SECRETS is unset).
ask_generate_secrets() {
  if [[ "${GENERATE_SECRETS:-ask}" == "yes" ]]; then return 0; fi
  if [[ "${GENERATE_SECRETS:-ask}" == "no" ]]; then return 1; fi
  if [[ -t 0 ]]; then
    local ans=""
    read -rp "Generate strong random secrets instead of the defaults? [y/N] " ans || true
    [[ "$ans" =~ ^[Yy]$ ]]
  else
    return 1
  fi
}

NEEDS_APP_SECRET=0
if grep -q '^APP_SECRET=change-me\|^APP_SECRET=$' "$ENV_FILE" || ! grep -q '^APP_SECRET=.' "$ENV_FILE"; then
  NEEDS_APP_SECRET=1
fi

# The DB password is baked into the Postgres data volume on first init,
# so it is only ever offered on a fresh install: changing .env afterwards
# would lock the app out (Postgres ignores POSTGRES_PASSWORD once the
# data dir exists). To rotate later, change it inside Postgres first.
# NOTE: keep it URL-safe — it is interpolated into DATABASE_URL in
# compose.yml, so characters like @ / : ? # would break parsing.
NEEDS_DB_PASSWORD=0
if [[ "$FRESH_ENV" -eq 1 ]] && grep -q '^POSTGRES_PASSWORD=umami' "$ENV_FILE"; then
  NEEDS_DB_PASSWORD=1
fi

if [[ "$NEEDS_APP_SECRET" -eq 1 || "$NEEDS_DB_PASSWORD" -eq 1 ]]; then
  if ask_generate_secrets; then
    if command -v openssl >/dev/null 2>&1; then
      SECRET="$(openssl rand -hex 32)"
      DBPASS="$(openssl rand -hex 24)"
    else
      SECRET="$(head -c 64 /dev/urandom | od -An -tx1 | tr -d ' \n')"
      DBPASS="$(head -c 24 /dev/urandom | od -An -tx1 | tr -d ' \n')"
    fi
    if [[ "$NEEDS_APP_SECRET" -eq 1 ]]; then
      echo "==> Generating random APP_SECRET"
      sed -i "s|^APP_SECRET=.*|APP_SECRET=$SECRET|" "$ENV_FILE"
    fi
    if [[ "$NEEDS_DB_PASSWORD" -eq 1 ]]; then
      echo "==> Generating random POSTGRES_PASSWORD"
      sed -i "s|^POSTGRES_PASSWORD=.*|POSTGRES_PASSWORD=$DBPASS|" "$ENV_FILE"
    fi
  else
    echo "==> Keeping default secrets (simple install)."
    echo "    Re-run with GENERATE_SECRETS=yes ./run.sh to randomize them."
  fi
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