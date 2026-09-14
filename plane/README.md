# Plane on VPS

Self-hosted [Plane](https://plane.so) project management (community edition)
via upstream's `setup.sh`, deployed with Docker Compose (proxy, web, api,
worker, Postgres, Valkey, RabbitMQ, MinIO).

Unlike the other services here, Plane brings its own installer: `run.sh`
drives `./setup.sh install|start` and then applies this repo's conventions
(localhost-only ports, generated secrets) on top. `setup.sh` is committed
with one commented compatibility fix (compact GitHub API JSON broke its
version check).

## Quick start (one command)

Requires Docker + Docker Compose on the server. First boot pulls ~10 images
and runs DB migrations, so allow several minutes.

```bash
./run.sh
```

That one command:

1. Creates `.env` from `.env.example` (port/domain overrides, if missing)
2. Runs `./setup.sh install` on first run (downloads compose + env as v1.4.2)
3. Points `plane-app/plane.env` at localhost:8088 (+ CORS) and generates
   `SECRET_KEY` / `LIVE_SERVER_SECRET_KEY`
4. Binds Plane's proxy ports to 127.0.0.1
5. Provides the minio image from Quay (`minio/minio` on Docker Hub is
   retired — without this, upstream's pull step fails)
6. Starts everything and waits until http://localhost:8088 answers 200

Open the printed URL and create the admin account on first visit.

`.env` and `plane-app/` (holds `plane.env` secrets) are git-ignored.

## Updating

```bash
./update.sh
```

If already on the latest stable tag it just ensures Plane is running.
Otherwise it runs upstream `./setup.sh upgrade` (refreshes compose + env,
preserving our ports/URLs), re-applies the localhost bind, refreshes the
minio retag, restarts, and waits until healthy.

## Production domain

In production Plane gets a domain via Caddy (see `../caddy` — block with
the required proxy headers is already there, commented):

```caddyfile
plane.example.com {
	reverse_proxy host.docker.internal:8088 {
		header_up X-Forwarded-Proto {scheme}
		header_up X-Forwarded-Host {host}
		...
	}
}
```

Then set the domain overrides in `.env` and re-run `./run.sh` (it rewrites
them into `plane.env`; required for correct links, CORS, and uploads):

```dotenv
PLANE_APP_DOMAIN=plane.example.com
PLANE_WEB_URL=https://plane.example.com
PLANE_CORS_ORIGINS=https://plane.example.com
```

## Common commands

```bash
./run.sh                         # first start / recreate everything
./update.sh                      # update to latest stable
./restart.sh                     # restart all Plane services
./stop.sh                        # stop (keeps data + config)
./setup.sh backup                # full backup into plane-app/backup/
docker compose -f plane-app/docker-compose.yaml --env-file plane-app/plane.env ps
```

Data lives in named Docker volumes (`pgdata`, `uploads`, `redisdata`, ...),
so it survives restarts and updates.

## Pushing to GitHub

This folder is a standalone git repository. `.env` and generated
`plane-app/` are git-ignored; `setup.sh` + scripts are committed.

```bash
git init
git add .
git commit -m "Initial plane setup"
git branch -M main
git remote add origin https://github.com/<you>/<repo>.git
git push -u origin main
```

On the VPS:

```bash
git clone https://github.com/<you>/<repo>.git
cd <repo>
./run.sh
```