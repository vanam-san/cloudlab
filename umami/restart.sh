#!/usr/bin/env bash
# Restart Umami: recreates app + db containers, then waits until the app
# answers on localhost again. Data in the umami-db volume is untouched.
set -euo pipefail

cd "$(dirname "$0")"

# shellcheck disable=SC1091
source .env 2>/dev/null || true

echo "==> Restarting Umami"
docker compose restart

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
echo "Umami restarted and responding at $URL"