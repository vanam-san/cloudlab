# Caddy on VPS

[Caddy](https://caddyserver.com/docs/) reverse proxy with automatic HTTPS,
using the official `caddy:latest` image, deployed with Docker Compose.

Backend apps run in sibling compose projects (e.g. `../umami`) on the
shared `cloudlab-proxy` Docker network and are reachable from Caddy via
Docker DNS names (e.g. `umami:3000`, `beszel:8090`, `sure:3000`,
`glance:8080`, `plane:80`, `checkmk:5000`,
`uptime-kuma:3001`, `checkmate:52345`). Localhost port bindings are kept for direct
local access, but Caddy always uses the shared network.

## Quick start (one command)

Requires Docker + Docker Compose on the server. Ports 80 and 443 must be free.

```bash
./run.sh
```

That one command:

1. Creates `.env` from `.env.example` (if missing)
2. Creates `tailscale-ips.caddy` from its `.example` (if missing) —
   put your tailnet IPs there before exposing any site
3. Pulls the latest Caddy image
4. Validates the Caddyfile
5. Starts Caddy and waits until healthy

## Adding a site

Point the domain's DNS at this server, edit `Caddyfile`:

```caddyfile
analytics.example.com {
	import tailscale-only
	reverse_proxy umami:3000
}
```

`import tailscale-only` restricts the site to your tailnet (recommended
default in this template — set your IPs in `tailscale-ips.caddy`).
For a public site, omit that line.

Then reload without downtime:

```bash
docker compose exec caddy caddy reload --config /etc/caddy/Caddyfile --adapter caddyfile
```

Caddy obtains and renews the TLS certificate automatically. Certificates
and config persist in the `caddy-data` / `caddy-config` Docker volumes.

> **Naming rule:** the service you proxy must have a globally unique
> compose service name — it becomes DNS on the shared `cloudlab-proxy`
> network for every stack. Never use generic names (`web`, `api`, `db`);
> name it after the app (`sure`, not `web`) and keep the Caddy upstream
> on the container-internal port.

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
docker compose exec caddy caddy reload --config /etc/caddy/Caddyfile --adapter caddyfile      # apply Caddyfile changes
docker compose down        # stop (keeps certificates)
docker compose down -v     # stop + delete certificates/config
```

## Using this folder as a template

This folder is self-contained: copy it out of this template repo to use
it on its own (or clone this repo with sparse-checkout). `.env` and
`tailscale-ips.caddy` are git-ignored; the Caddyfile itself contains no
secrets (but remember to set your own tailnet IPs in `tailscale-ips.caddy`).

```bash
cp -r caddy ~/my-caddy && cd ~/my-caddy
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