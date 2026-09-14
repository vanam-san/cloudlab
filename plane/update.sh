#!/usr/bin/env bash
# Update Plane community edition.
# Upstream path is `./setup.sh upgrade`: interactive Continue prompt,
# refreshes compose + env (preserving plane.env keys, so our ports/URLs
# survive), then pulls images. Two local realities handled here:
# - the prompt is answered non-interactively with "y";
# - upgrade's pull step fails on the retired minio/minio repo (tolerated:
#   files are refreshed before it), minio comes from Quay instead.
# Flow:
# 1. If already on the latest stable tag -> just ensure running + wait.
# 2. Else pipe "y" into setup.sh upgrade, re-apply the 127.0.0.1 proxy
#    bind (upgrade re-downloads compose), ensure the minio retag.
# 3. Start (pulls missing images, runs migrations) and wait for 200.
set -euo pipefail

cd "$(dirname "$0")"

# shellcheck disable=SC1091
source .env 2>/dev/null || true
PLANE_PORT="${PLANE_PORT:-9080}"

echo "==> Resolving latest stable tag"
LATEST="$(curl -fsSI https://github.com/makeplane/plane/releases/latest | grep -i '^location:' | grep -o 'tag/.*' | cut -d/ -f2 | tr -d '\r')"
CURRENT="$(grep -E '^APP_RELEASE=' plane-app/plane.env | cut -d= -f2)"
echo "    current: $CURRENT / latest: $LATEST"

if [[ -n "$LATEST" && "$LATEST" == "$CURRENT" ]]; then
  echo "==> Already on latest, ensuring Plane is running"
else
  echo "==> Upgrading via upstream setup.sh"
  # shellcheck disable=SC2116
  echo y | ./setup.sh upgrade || true

  # Re-apply localhost-only proxy bind (upgrade re-downloaded compose).
  if ! grep -q "host_ip: 127.0.0.1" plane-app/docker-compose.yaml; then
    echo "==> Binding Plane proxy to 127.0.0.1"
    python3 - plane-app/docker-compose.yaml <<'EOF'
import sys
p = sys.argv[1]
out = []
for l in open(p).read().split('\n'):
    out.append(l)
    if 'published: ${LISTEN_' in l and l.rstrip().endswith('}'):
        out.append(l[:len(l) - len(l.lstrip())] + 'host_ip: 127.0.0.1')
open(p, 'w').write('\n'.join(out))
EOF
  fi

  # Minio image (Docker Hub repo retired, Quay provides it).
  if ! docker image inspect minio/minio:latest >/dev/null 2>&1; then
    echo "==> Providing minio image from Quay"
    docker pull quay.io/minio/minio:latest
    docker tag quay.io/minio/minio:latest minio/minio:latest
  fi
fi

echo "==> Starting Plane"
./setup.sh start

echo "==> Waiting for Plane to answer"
URL="http://localhost:$PLANE_PORT"
for i in $(seq 1 120); do
  if curl -fsS -o /dev/null "$URL/" >/dev/null 2>&1; then
    break
  fi
  [[ $i -eq 120 ]] && { echo "Timed out waiting for Plane"; exit 1; }
  sleep 5
done

echo ""
echo "Plane updated and responding at $URL"