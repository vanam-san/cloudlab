#!/usr/bin/env bash
# One-command deploy for Checkmate: ./run.sh
# Upstream docs: https://checkmate.so/docs/getting-started/installation#option-1-docker
# 1. Creates .env from .env.example (git-ignored, never committed).
# 2. Offers to generate a strong random JWT_SECRET. Simple installs keep
#    the default. (Rotating it later is safe anytime — it only logs
#    everyone out. No database password exists: Mongo has no auth, like
#    upstream, and is reachable only from the app.)
# 3. Pulls the Checkmate + Mongo images.
# 4. Starts the stack and waits until the app answers on localhost.
# After the first start, create the admin account in the web UI.
# It is idempotent — safe to re-run any time.
set -euo pipefail

cd "$(dirname "$0")"

ENV_FILE=".env"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "==> Creating $ENV_FILE from .env.example"
  cp .env.example "$ENV_FILE"
fi

# Load .env for the values read below. Defaults apply when keys are
# missing (e.g. a .env created before those keys existed).
set -a
# shellcheck disable=SC1091
source "$ENV_FILE" 2>/dev/null || true
set +a

echo "==> Ensuring shared proxy network (cloudlab-proxy)"
docker network inspect cloudlab-proxy >/dev/null 2>&1 || docker network create cloudlab-proxy

# Random hex secret; openssl preferred, /dev/urandom as fallback.
gen_hex() {
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -hex "$1"
  else
    head -c "$1" /dev/urandom | od -An -tx1 | tr -d ' \n'
  fi
}

# Simple install by default: keep the template default. Opt in to a
# strong random secret with GENERATE_SECRETS=yes, or answer the prompt
# below. Non-interactive runs keep the default (GENERATE_SECRETS unset).
ask_generate_secrets() {
  if [[ "${GENERATE_SECRETS:-ask}" == "yes" ]]; then return 0; fi
  if [[ "${GENERATE_SECRETS:-ask}" == "no" ]]; then return 1; fi
  if [[ -t 0 ]]; then
    local ans=""
    read -rp "Generate a strong random JWT secret instead of the default? [y/N] " ans || true
    [[ "$ans" =~ ^[Yy]$ ]]
  else
    return 1
  fi
}

if grep -q '^JWT_SECRET=change-me' "$ENV_FILE"; then
  if ask_generate_secrets; then
    echo "==> Generating random JWT_SECRET"
    sed -i "s|^JWT_SECRET=.*|JWT_SECRET=$(gen_hex 32)|" "$ENV_FILE"
    set -a
    # shellcheck disable=SC1091
    source "$ENV_FILE" 2>/dev/null || true
    set +a
  else
    echo "==> Keeping default JWT secret (simple install)."
    echo "    Re-run with GENERATE_SECRETS=yes ./run.sh to randomize it."
  fi
fi

echo "==> Pulling latest images (${CHECKMATE_IMAGE:-ghcr.io/bluewave-labs/checkmate:latest})"
docker compose pull

echo "==> Starting Checkmate"
docker compose up -d

echo "==> Waiting for Checkmate to become ready"
URL="http://localhost:${CHECKMATE_PORT:-8073}"
# Accept any 2xx/3xx: `/` serves the app (setup/login page on fresh data).
for i in $(seq 1 60); do
  CODE="$(curl -s -o /dev/null -w '%{http_code}' "$URL/" 2>/dev/null || echo 000)"
  if [[ "$CODE" =~ ^[23] ]]; then
    break
  fi
  [[ $i -eq 60 ]] && { echo "Timed out waiting for Checkmate (last HTTP $CODE)"; exit 1; }
  sleep 2
done

echo ""
echo "Checkmate is up!"
echo "  URL:   $URL"
echo "  Create the admin account in the web UI on first visit."
