# Uptime Kuma on VPS

Self-hosted [Uptime Kuma](https://github.com/louislam/uptime-kuma)
uptime monitoring (HTTP(S), TCP, DNS, ping, push monitors with
notifications) using the official `louislam/uptime-kuma:2` image,
deployed with Docker Compose.

Single container, no database: everything (monitors, history, users)
lives in `/app/data`.

## Quick start (one command)

Requires Docker + Docker Compose on the server.

```bash
./run.sh
```

That one command:

1. Creates `.env` from `.env.example` (if missing)
2. Pulls the latest Uptime Kuma image
3. Starts it on localhost:3002 and waits until ready

Open the printed URL and create the admin account on first visit. No
other setup is needed — add your first monitor right after.

`.env` is git-ignored; secrets are never committed.

## Configuration

Edit `.env` after the first run if needed:

| Variable | Default | Purpose |
| --- | --- | --- |
| `UPTIME_KUMA_IMAGE` | `louislam/uptime-kuma:2` | Uptime Kuma image (bump tag to update) |
| `UPTIME_KUMA_PORT` | `3002` | Host port (localhost-only; container port is always 3001) |

The app port is bound to `127.0.0.1` only — in production it gets a
domain via Caddy (see `../caddy`), never a direct public port.

## Updating

Per upstream docs
([Update](https://github.com/louislam/uptime-kuma#update)):

```bash
./update.sh
```

It pulls the latest image and recreates the container (`down` +
`up -d`), then waits until the app responds again. Data in the
`uptime-kuma` volume is preserved and migrated automatically.

## Production domain

In production Uptime Kuma gets a domain via Caddy (see `../caddy`),
gated by Basic Auth like every other site:

```caddyfile
uptime.domain {
	import basic-auth
	reverse_proxy uptime-kuma:3001
}
```

(`import basic-auth` prompts for the browser login before the app's own
login — the default for every site; optionally add `import tailscale-only`
for a tailnet allowlist on top. See `../caddy/Caddyfile`. Point the
domain's DNS at the VPS first, then reload Caddy. No app-side URL setting
is needed. If you monitor the domain itself with Uptime Kuma, use the
public URL as the monitor target once DNS resolves.)

## Common commands

```bash
./run.sh                         # first start / recreate everything
./update.sh                      # update Uptime Kuma, data preserved
docker compose logs -f uptime-kuma
docker compose down              # stop (keeps data)
docker compose down -v           # stop + delete data volume
```

Data lives in the named Docker volume `uptime-kuma`, so it survives
restarts and updates. Back it up by snapshotting the volume:

```bash
docker compose run --rm -v uptime-kuma:/data -v $(pwd):/backup ubuntu \
  tar czf /backup/uptime-kuma-backup.tar.gz -C /data .
```

## Using this folder as a template

This folder is self-contained: copy it out of this template repo to use
it on its own (or clone this repo with sparse-checkout). `.env` is
git-ignored.

```bash
cp -r uptime-kuma ~/my-uptime-kuma && cd ~/my-uptime-kuma
git init
git add .
git commit -m "Initial uptime-kuma setup"
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

Restore data from a backup by restoring the `uptime-kuma` Docker volume
on the target server and running `./run.sh`.

## Health / reverse proxy

It is deployed behind Caddy for HTTPS rather than hitting
`http://server:3002` directly. With Caddyfile:

```caddyfile
uptime.domain {
	import basic-auth
	reverse_proxy uptime-kuma:3001
}
```

(Caddy runs with host networking and proxies to the host-mapped port
`localhost:3002`. `import basic-auth` is
the default gate for every site — browser login before the app's own
login; optionally add `import tailscale-only` for a tailnet allowlist on
top. See `../caddy/Caddyfile`.)
