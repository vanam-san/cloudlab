#!/usr/bin/env bash
# One-command deploy for Checkmk: ./run.sh
# 1. Creates .env from .env.example (git-ignored, never committed).
# 2. Offers to generate a strong random CMK_PASSWORD (cmkadmin login) on
#    first install. Simple installs keep the default.
# 3. Pulls the Checkmk image.
# 4. Starts the stack (the site is created automatically on first boot)
#    and waits until the web UI answers on localhost.
# After the first start, log in as cmkadmin and change the password
# (see README.md).
# It is idempotent — safe to re-run any time.
set -euo pipefail

cd "$(dirname "$0")"

# Compose project name (directory basename, lowercased like compose does)
# — volume names are prefixed with it, so derive it instead of hardcoding.
PROJECT_NAME="${COMPOSE_PROJECT_NAME:-$(basename "$PWD" | tr '[:upper:]' '[:lower:]')}"

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
# strong random password with GENERATE_SECRETS=yes, or answer the prompt
# below. Non-interactive runs keep the default (GENERATE_SECRETS unset).
ask_generate_secrets() {
  if [[ "${GENERATE_SECRETS:-ask}" == "yes" ]]; then return 0; fi
  if [[ "${GENERATE_SECRETS:-ask}" == "no" ]]; then return 1; fi
  if [[ -t 0 ]]; then
    local ans=""
    read -rp "Generate a strong random admin password instead of the default? [y/N] " ans || true
    [[ "$ans" =~ ^[Yy]$ ]]
  else
    return 1
  fi
}

# CMK_PASSWORD is baked into the site volume at creation, so it is only
# ever offered on a fresh install: changing .env afterwards does not
# change the cmkadmin login (do that in the UI under Setup > Users).
if grep -q '^CMK_PASSWORD=change-me' "$ENV_FILE"; then
  if ! docker volume inspect "${PROJECT_NAME}_checkmk" >/dev/null 2>&1; then
    if ask_generate_secrets; then
      echo "==> Generating random CMK_PASSWORD"
      sed -i "s|^CMK_PASSWORD=.*|CMK_PASSWORD=$(gen_hex 16)|" "$ENV_FILE"
      set -a
      # shellcheck disable=SC1091
      source "$ENV_FILE" 2>/dev/null || true
      set +a
    else
      echo "==> Keeping default admin password (simple install)."
      echo "    Re-run with GENERATE_SECRETS=yes ./run.sh to randomize it."
    fi
  else
    echo "==> Site volume exists, keeping existing CMK_PASSWORD."
  fi
fi

echo "==> Pulling latest image (${CHECKMK_IMAGE:-checkmk/check-mk-raw:2.4.0-latest})"
docker compose pull

echo "==> Starting Checkmk"
docker compose up -d

echo "==> Waiting for Checkmk web UI to become ready"
SITE="${CMK_SITE_ID:-cmk}"
URL="http://localhost:${CHECKMK_PORT:-8072}"
# Poll the site path (`/` has no content; the site lives under /<site>/).
# Accept any 2xx/3xx: it redirects to the login page once ready. First
# boot creates the site and can take several minutes.
for i in $(seq 1 90); do
  CODE="$(curl -s -o /dev/null -w '%{http_code}' "$URL/$SITE/" 2>/dev/null || echo 000)"
  if [[ "$CODE" =~ ^[23] ]]; then
    break
  fi
  [[ $i -eq 90 ]] && { echo "Timed out waiting for Checkmk (last HTTP $CODE)"; exit 1; }
  sleep 5
done

echo ""
echo "Checkmk is up!"
echo "  URL:   $URL/$SITE/"
echo "  Login: cmkadmin (password is CMK_PASSWORD in .env — change it"
echo "         after login under Setup > Users > cmkadmin)"
