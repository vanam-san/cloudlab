# Checkmate on VPS

Self-hosted [Checkmate](https://checkmate.so) uptime and infrastructure
monitoring (uptime, PageSpeed, infrastructure, incidents, status pages)
using the official all-in-one `ghcr.io/bluewave-labs/checkmate:latest`
image plus MongoDB, deployed with Docker Compose.

The `compose.yml` here is upstream's
[reference Compose file](https://checkmate.so/docs/getting-started/installation#option-1-docker)
with small local adaptations (localhost-only port, parameterized image,
shared `cloudlab-proxy` network — all marked in the file).

## Quick start (one command)

Requires Docker + Docker Compose on the server (multi-arch image:
x86_64 and ARM both work).

```bash
./run.sh
```

That one command:

1. Creates `.env` from `.env.example` (if missing). Simple installs keep
   the defaults; answer the prompt (or run with `GENERATE_SECRETS=yes`)
   for a strong random `JWT_SECRET`
2. Pulls the Checkmate + MongoDB images
3. Starts Checkmate + MongoDB on localhost:8073 and waits until ready

Open the printed URL and create the admin account on first visit.

`.env` is git-ignored; secrets are never committed.

## Configuration

Edit `.env` after the first run if needed:

| Variable | Default | Purpose |
| --- | --- | --- |
| `CHECKMATE_IMAGE` | `ghcr.io/bluewave-labs/checkmate:latest` | Checkmate image (bump tag to update) |
| `CHECKMATE_PORT` | `8073` | Host port (localhost-only; container port is always 52345) |
| `MONGO_DB` | `uptime_db` | Mongo database name |
| `CLIENT_HOST` | `http://localhost:8073` | Public URL of the app (CORS + notification links; set to the domain in production) |
| `JWT_SECRET` | `change-me` (auto-generated) | Auth token secret (safe to rotate anytime — just logs everyone out) |
| `ENCRYPTION_KEY` | _(empty)_ | Optional extra encryption key |
| `LOG_LEVEL` | `info` | Server log level (`error`, `warn`, `info`, `debug`) |

There is no database password: like upstream, MongoDB runs without auth
and is reachable only from the app on the private compose network.

The app port is bound to `127.0.0.1` only — in production it gets a
domain via Caddy (see `../caddy`), never a direct public port.

## Monitoring Docker containers (optional)

Upstream supports monitoring host containers via the Docker socket. This
is **off by default**: socket access is root-equivalent on the host, so
enable it deliberately with a `compose.override.yaml` next to
`compose.yml` (never committed — add it to `.gitignore` yourself if you
fork this folder):

```yaml
services:
  checkmate:
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
```

then `docker compose up -d checkmate`.

## Updating

Pull the new image and recreate (upstream has no separate migration step
for the all-in-one image):

```bash
./update.sh
```

It pulls the latest images and recreates the containers (`down` +
`up -d`), then waits until the app responds again. Data in the
`mongo-data` volume is preserved.

## Production domain

In production Checkmate gets a domain via Caddy (see `../caddy`),
restricted to tailnet clients like every other site:

```caddyfile
checkmate.example.com {
	import tailscale-only
	reverse_proxy checkmate:52345
}
```

(`import tailscale-only` restricts the site to tailnet clients; see
`../caddy/Caddyfile`. Point the domain's DNS at the VPS first, then
reload Caddy.)

Because the app is reached at another origin now, tell it its public
URL — set in `.env` and re-run `./run.sh` (restart recreates the app
with the new value):

```dotenv
CLIENT_HOST=https://checkmate.example.com
```

Without this, the app still loads, but notification links and some
cross-origin calls use the wrong host.

## Common commands

```bash
./run.sh                         # first start / recreate everything
./update.sh                      # update Checkmate, data preserved
docker compose logs -f checkmate
docker compose down              # stop (keeps data)
docker compose down -v           # stop + delete database volume
```

Data lives in the named Docker volume `mongo-data`, so it survives
restarts and updates. Back it up by snapshotting the volume:

```bash
docker compose run --rm -v mongo-data:/data -v $(pwd):/backup ubuntu \
  tar czf /backup/checkmate-backup.tar.gz -C /data .
```

## Using this folder as a template

This folder is self-contained: copy it out of this template repo to use
it on its own (or clone this repo with sparse-checkout). `.env` is
git-ignored.

```bash
cp -r checkmate ~/my-checkmate && cd ~/my-checkmate
git init
git add .
git commit -m "Initial checkmate setup"
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

Restore data from a backup by restoring the `mongo-data` Docker volume
on the target server and running `./run.sh`.

## Health / reverse proxy

It is deployed behind Caddy for HTTPS rather than hitting
`http://server:8073` directly. With Caddyfile:

```caddyfile
checkmate.example.com {
	import tailscale-only
	reverse_proxy checkmate:52345
}
```

(Caddy reaches Checkmate over the shared `cloudlab-proxy` Docker network via
the container DNS name `checkmate:52345` — plain `localhost` inside the
Caddyfile would mean the Caddy container itself. `import tailscale-only`
restricts the site to tailnet clients; see `../caddy/Caddyfile`.)
