# Caddy on VPS

[Caddy](https://caddyserver.com/docs/) reverse proxy with automatic HTTPS,
using the official `caddy:latest` image, deployed with Docker Compose.

Backend apps run in sibling compose projects (e.g. `../umami`) on host
ports and are reachable from Caddy as `host.docker.internal:<port>`.

## Quick start (one command)

Requires Docker + Docker Compose on the server. Ports 80 and 443 must be free.

```bash
./run.sh
```

That one command:

1. Creates `.env` from `.env.example` (if missing)
2. Pulls the latest Caddy image
3. Validates the Caddyfile
4. Starts Caddy and waits until healthy

## Adding a site

Point the domain's DNS at this server, edit `Caddyfile`:

```caddyfile
analytics.example.com {
	reverse_proxy host.docker.internal:3000
}
```

Then reload without downtime:

```bash
docker compose exec caddy caddy reload
```

Caddy obtains and renews the TLS certificate automatically. Certificates
and config persist in the `caddy-data` / `caddy-config` Docker volumes.

## Updating

Per upstream docs ([Install](https://caddyserver.com/docs/install),
Docker image):

```bash
./update.sh
```

It pulls the latest `caddy` image and recreates the container. Certs,
config and the Caddyfile are untouched (volumes + bind mount), so there
is no re-issuance and no downtime beyond the container restart.

## Common commands

```bash
./run.sh                                    # pull latest + (re)start
./update.sh                                 # update Caddy
docker compose logs -f caddy
docker compose exec caddy caddy reload      # apply Caddyfile changes
docker compose down        # stop (keeps certificates)
docker compose down -v     # stop + delete certificates/config
```

## Pushing to GitHub

This folder is a standalone git repository. `.env` is git-ignored; the
Caddyfile itself contains no secrets.

```bash
git init
git add .
git commit -m "Initial caddy setup"
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