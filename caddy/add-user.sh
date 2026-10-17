#!/usr/bin/env bash
# add-user.sh — interactively add a new user to Caddy's Basic Auth file.
#
# Prompts for a username and password, appends a `username <bcrypt-hash>` entry to
# the `basic_auth` block in ./basic-auth.caddy, validates the Caddyfile with a
# throwaway Caddy container, then reloads Caddy.
#
# Caddy stores password hashes (bcrypt by default), not plaintext.
# basic-auth.caddy is git-ignored — never commit it.
set -euo pipefail

cd "$(dirname "$0")"

AUTH_FILE="basic-auth.caddy"
ENV_FILE=".env"

[[ -f "$AUTH_FILE" ]] || {
  echo "basic-auth.caddy not found. Run ./run.sh first to generate it." >&2
  exit 1
}

if ! command -v docker >/dev/null 2>&1 || ! docker info >/dev/null 2>&1; then
  echo "Docker is required to generate a bcrypt hash for the password." >&2
  exit 1
fi

# shellcheck disable=SC1091
source "$ENV_FILE" 2>/dev/null || true
IMAGE="${CADDY_IMAGE:-caddy:latest}"

# --- collect credentials -----------------------------------------------------
read -rp "New Basic Auth username: " USER
[[ -n "$USER" && "$USER" =~ ^[A-Za-z0-9._@+-]+$ ]] || {
  echo "Invalid username: use only letters, digits, . _ @ + -" >&2
  exit 1
}

# reject duplicates (unquoted or quoted form)
ESC_USER="${USER//./\\.}"
ESC_USER="${ESC_USER//+/\\+}"
if grep -Eq "^[[:space:]]${ESC_USER}[[:space:]]" "$AUTH_FILE" \
   || grep -Eq "^[[:space:]]\"${ESC_USER}\"[[:space:]]" "$AUTH_FILE"; then
  echo "User '$USER' already exists in $AUTH_FILE" >&2
  exit 1
fi

read -rsp "New Basic Auth password: " PASS; echo
[[ -n "$PASS" ]] || { echo "Password must not be empty" >&2; exit 1; }
read -rsp "Confirm password: " PASS2; echo
[[ "$PASS" == "$PASS2" ]] || { echo "Passwords do not match" >&2; exit 1; }

HASH="$(printf '%s\n' "$PASS" | docker run --rm -i "$IMAGE" caddy hash-password)"
if [[ -z "$HASH" ]]; then
  echo "Failed to generate bcrypt hash for password" >&2
  exit 1
fi

# Tab-indented entry: username <bcrypt-hash>
ENTRY=$'\t'"${USER} ${HASH}"

# --- build candidate file in a temp file (never in place yet) ----------------
TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

if ! ENTRY="$ENTRY" awk '
  { lines[NR] = $0 }
  END {
    inserted = 0
    for (i = 1; i <= NR; i++) {
      print lines[i]
      if (!inserted && index(lines[i], "basic_auth @needs_auth {") > 0) {
        print ENVIRON["ENTRY"]
        inserted = 1
      }
    }
    if (!inserted) exit 1
  }' "$AUTH_FILE" > "$TMP"; then
  echo "Could not find the basic_auth block in $AUTH_FILE" >&2
  exit 1
fi

# --- validate before touching the live file ----------------------------------
if [[ ! -f tailscale-ips.caddy ]]; then
  cp tailscale-ips.caddy.example tailscale-ips.caddy
fi

docker pull -q "$IMAGE" >/dev/null 2>&1 || true
if ! docker run --rm \
  -v "$PWD/Caddyfile:/etc/caddy/Caddyfile:ro" \
  -v "$TMP:/etc/caddy/basic-auth.caddy:ro" \
  -v "$PWD/tailscale-ips.caddy:/etc/caddy/tailscale-ips.caddy:ro" \
  "$IMAGE" caddy validate --adapter caddyfile --config /etc/caddy/Caddyfile >/dev/null; then
  echo "Caddyfile validation failed — $AUTH_FILE was NOT changed." >&2
  exit 1
fi

# --- publish in place (keeps the same inode, so bind mounts stay valid) ------
cat "$TMP" > "$AUTH_FILE"
rm -f "$TMP"
trap - EXIT

echo "Added user '$USER' to $AUTH_FILE"

# --- apply to running Caddy --------------------------------------------------
if docker ps --format '{{.Names}}' | grep -qx caddy; then
  echo "==> Reloading Caddy"
  docker compose exec -T caddy caddy reload --config /etc/caddy/Caddyfile --adapter caddyfile
else
  echo "Caddy container is not running — start it with ./run.sh (or docker compose up -d)."
fi

echo "Done. Credentials in $AUTH_FILE are stored as bcrypt hashes — keep the file private."
