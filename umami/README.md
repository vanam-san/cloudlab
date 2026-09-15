# Umami on VPS

Self-hosted [Umami](https://umami.is/docs) web analytics using the official
prebuilt image `docker.umami.is/umami-software/umami:latest` plus a
PostgreSQL database, deployed with Docker Compose.

## Quick start (one command)

Requires Docker + Docker Compose on the server.

```bash
./run.sh
```

That one command:

1. Creates `.env` from `.env.example` (if missing) with a random `APP_SECRET`
2. Pulls the latest Umami image
3. Starts Umami + PostgreSQL
4. Waits until healthy, then prints the URL

Open the printed URL and log in with user `admin` / password `umami`
(change it immediately after first login).

## Configuration

Edit `.env` after the first run if needed:

| Variable            | Default                                    | Purpose                  |
| ------------------- | ------------------------------------------ | ------------------------ |
| `UMAMI_IMAGE`       | `docker.umami.is/umami-software/umami:latest` | Umami Docker image   |
| `UMAMI_PORT`        | `3000`                                     | Host port                |
| `POSTGRES_USER`     | `umami`                                    | DB user                  |
| `POSTGRES_PASSWORD` | `umami` (auto)                             | DB password              |
| `POSTGRES_DB`       | `umami`                                    | DB name                  |
| `APP_SECRET`        | `change-me` (auto-generated)               | Auth token secret        |

`.env` is git-ignored; secrets are never committed.

The app port is bound to `127.0.0.1` only — in production it gets a
domain via Caddy (see `../caddy`), never a direct public port.

## Updating

Per upstream docs ([Getting updates](https://umami.is/docs/updates)):

```bash
./update.sh
```

It pulls the latest image and recreates the containers (`down` + `up -d`,
as the docs prescribe). Data in the `umami-db` volume is preserved and
migrations run automatically on startup.

After MAJOR upgrades, refresh Postgres planner statistics (schema
migrations can leave them stale and slow down dashboard queries):

```bash
docker compose exec db psql -U umami -d umami -c "ANALYZE;"
```

Safe on a live database; dashboard queries return to normal speed after.

## Common commands

```bash
./run.sh            # pull latest + (re)start
./update.sh         # update Umami per upstream docs
docker compose up -d
docker compose logs -f umami
docker compose down        # stop (keeps data)
docker compose down -v     # stop + delete database volume
```

Database data lives in the named Docker volume `umami-db`, so it survives
restarts and updates.

## Deploying / backing up / GitHub

This folder is a standalone git repository. Push it up and run it on any VPS:

```bash
git init
git add .
git commit -m "Initial umami setup"
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

Restore data from a backup by restoring the `umami-db` Docker volume on the
target server and running `./run.sh`.

## Health / reverse proxy

It is deployed behind Caddy for HTTPS rather than hitting
`http://server:3000` directly. With Caddyfile:

```caddyfile
analytics.example.com {
	import tailscale-only
	reverse_proxy umami:3000
}
```

(Caddy reaches Umami over the shared `cloudlab-proxy` Docker network via
the container DNS name `umami:3000` — plain `localhost` inside the
Caddyfile would mean the Caddy container itself. `import tailscale-only`
restricts the site to tailnet clients; see `../caddy/Caddyfile`.)