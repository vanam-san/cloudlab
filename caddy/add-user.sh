#!/usr/bin/env bash
# add-user.sh — interactively add a new user to Caddy's Basic Auth file.
#
# Prompts for a username and password, appends a `user base64(pass)` entry to
# the `basic_auth` block in ./basic-auth.caddy, validates the Caddyfile with a
# throwaway Caddy container, then reloads Caddy.
#
# Caddy's http_basic provider base64-decodes the stored password, so credentials
# are stored as `username base64(plaintext_password)`. basic-auth.caddy is
# git-ignored — never commit it.
set -euo pipefail

cd "$(dirname "$0")"

AUTH_FILE="basic-auth.caddy"
ENV_FILE=".env"

[[ -f "$AUTH_FILE" ]] || {
  echo "basic-auth.caddy not found. Run ./run.sh first to generate it." >&2
  exit 1
}

# shellcheck disable=SC1091
source "$ENV_FILE" 2>/dev/null || true
IMAGE="${CADDY_IMAGE:-caddy:latest}"

wait_healthy() {
  for i in $(seq 1 30); do
    STATUS="$(docker inspect caddy --format '{{.State.Health.Status}}' 2>/dev/null || echo starting)"
    [[ "$STATUS" == "healthy" ]] && return 0
    if [[ $i -eq 30 ]]; then
      echo "Timed out waiting for Caddy (status: $STATUS)" >&2
      return 1
    fi
    sleep 2
  done
  return 1
}

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
case "$PASS" in
  *\"*|*\\*) echo "Password must not contain double quotes or backslashes" >&2; exit 1 ;;
esac

# Tab-indented entry: username base64(password). Caddy base64-decodes the
# stored password and compares it with the plaintext sent by the client.
ENTRY=$'\t'"${USER} $(printf '%s' "$PASS" | base64 -w0)"

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

if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
  docker pull -q "$IMAGE" >/dev/null 2>&1 || true
  if ! docker run --rm \
    -v "$PWD/Caddyfile:/etc/caddy/Caddyfile:ro" \
    -v "$TMP:/etc/caddy/basic-auth.caddy:ro" \
    -v "$PWD/tailscale-ips.caddy:/etc/caddy/tailscale-ips.caddy:ro" \
    "$IMAGE" caddy validate --adapter caddyfile --config /etc/caddy/Caddyfile >/dev/null; then
    echo "Caddyfile validation failed — $AUTH_FILE was NOT changed." >&2
    exit 1
  fi
else
  echo "WARNING: docker unavailable — skipping validation" >&2
fi

# --- publish in place (keeps the same inode, so bind mounts stay valid) ------
cat "$TMP" > "$AUTH_FILE"
rm -f "$TMP"
trap - EXIT

echo "Added user '$USER' to $AUTH_FILE"

# --- apply to running Caddy --------------------------------------------------
if docker ps --format '{{.Names}}' | grep -qx caddy; then
  if ! docker exec caddy cat /etc/caddy/basic-auth.caddy | cmp -s - "$AUTH_FILE"; then
    echo "WARNING: the running Caddy container holds a stale copy of $AUTH_FILE"
    echo "(Docker bind-mounts single files by inode; the file was replaced earlier.)"
    read -rp "Recreate the Caddy container now so it picks up the new credentials? [y/N] " ANS
    if [[ "$ANS" =~ ^[Yy]$ ]]; then
      echo "==> Recreating Caddy"
      docker compose up -d --force-recreate caddy
      wait_healthy
    else
      echo "Skipping recreate; reload may not take effect until Caddy is restarted." >&2
    fi
  fi
  echo "==> Reloading Caddy"
  docker compose exec -T caddy caddy reload --config /etc/caddy/Caddyfile --adapter caddyfile
else
  echo "Caddy container is not running — start it with ./run.sh (or docker compose up -d)."
fi

echo "Done. Credentials in $AUTH_FILE are base64-encoded — keep the file private."
