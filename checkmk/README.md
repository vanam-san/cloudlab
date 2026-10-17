# Checkmk on VPS

Self-hosted [Checkmk](https://checkmk.com) (Raw edition — 100% open
source) infrastructure and application monitoring: one container holds
the whole site (web UI, core, history), deployed with Docker Compose
using the official image.

Upstream docs:
https://docs.checkmk.com/latest/en/introduction_docker.html

Pick this or [Beszel](../beszel/) (or both): Beszel is near-zero
maintenance with great dashboards; Checkmk is the full platform —
thousands of check plugins, auto-discovery, stateful alerting with
escalations, and long-term availability reporting.

## Quick start (one command)

Requires Docker + Docker Compose on the server (x86_64 only — the
upstream image is not built for ARM).

```bash
./run.sh
```

That one command:

1. Creates `.env` from `.env.example` (if missing). Simple installs keep
   the defaults; answer the prompt (or run with `GENERATE_SECRETS=yes`)
   for a strong random `CMK_PASSWORD`
2. Pulls the Checkmk image
3. Creates the site on localhost:8072 and waits until ready (first boot
   creates the site and can take several minutes)

Open the printed URL and log in as `cmkadmin`.

> **Change the default password immediately** under
> Setup > Users > cmkadmin. Until then anyone with local access can log
> in. (Changing `CMK_PASSWORD` in `.env` later does nothing — it is only
> read at site creation.)

`.env` is git-ignored; secrets are never committed.

## Monitoring hosts (agents)

No agent runs here by default — enroll each host you want monitored.
Two paths, both need the **agent receiver** (container port 8000), which
`compose.yml` leaves unpublished (closed) by default:

**Open the receiver** when you enroll your first external host
(agent-controller registration needs container port **8000**).
Internet-facing (firewall per agent IP) — add to the `checkmk` service
in `compose.yml`:

```yaml
    ports:
      - "127.0.0.1:${CHECKMK_PORT:-8072}:5000"
      - "8000:8000"
```

then `docker compose up -d checkmk` plus:

```bash
sudo ufw allow from <agent-ip> to any port 8000
```

On a tailnet instead, bind it to the tailnet interface so it never
touches the public internet:

```yaml
      - "<vps-tailnet-ip>:8000:8000"
```

**Enroll a host:**

1. On the host, install the agent package — download it from your own
   site: Setup > Agents > Linux (`check-mk-agent_*.deb/.rpm`), or
   Windows/macOS equivalents.
2. Register its controller against the receiver (TLS is automatic):
   `cmk-agent-ctl register --server <vps-ip-or-tailnet-ip>:8000 --site
   <site-id> --user cmkadmin` (it prompts for the password).
3. In the web UI: Setup > Hosts > Add host, run **service discovery**,
   activate changes. Data and graphs appear within minutes.

No Tailscale is required — use the public IP with the firewall rule, or
the tailnet IP with the bound port. The classic pull mode (server →
agent on 6556) also works but needs the agent reachable from here, so
prefer registration mode behind NAT.

## Configuration

Edit `.env` after the first run if needed:

| Variable | Default | Purpose |
| --- | --- | --- |
| `CHECKMK_IMAGE` | `checkmk/check-mk-raw:2.4.0-latest` | Checkmk image (bump tag to update) |
| `CHECKMK_PORT` | `8072` | Host port for the web UI (localhost-only) |
| `CMK_SITE_ID` | `cmk` | Site id (only before first init; also update tmpfs path in compose.yml) |
| `CMK_PASSWORD` | `change-me` (auto-generated) | `cmkadmin` password, read at site creation only |
| `TZ` | `UTC` | Site timezone (e.g. `Europe/Berlin`) |

The app port is bound to `127.0.0.1` only — in production it gets a
domain via Caddy (see `../caddy`), never a direct public port.

## Updating

Per upstream docs
([Update procedure](https://docs.checkmk.com/latest/en/update_major.html)):

```bash
./update.sh
```

It pulls the latest image and recreates the container (`down` +
`up -d`); the site migrates automatically on startup, then waits until
the web UI responds again. Data in the `checkmk` volume is preserved.

Back up the site before MAJOR upgrades — snapshot the volume:

```bash
docker compose run --rm -v checkmk:/data -v $(pwd):/backup ubuntu \
  tar czf /backup/checkmk-backup.tar.gz -C /data .
```

(or inside the container: `omd backup <site-id> /tmp/` and copy it out
with `docker compose cp`).

## Production domain

In production Checkmk gets a domain via Caddy (see `../caddy`), gated by
Basic Auth like every other site:

```caddyfile
checkmk.domain.dev {
	import basic-auth
	reverse_proxy checkmk:5000
}
```

(`import basic-auth` prompts for the browser login before the app's own
login — the default for every site; optionally add `import tailscale-only`
for a tailnet allowlist on top. See `../caddy/Caddyfile`. Point the
domain's DNS at the VPS first, then reload Caddy. No app-side URL setting
is needed — the `/cmk/` site path works behind the proxy as-is.)

## Common commands

```bash
./run.sh                         # first start / recreate everything
./update.sh                      # update Checkmk, site preserved
docker compose logs -f checkmk
docker compose exec checkmk omd status              # site status inside
docker compose down              # stop (keeps data)
docker compose down -v           # stop + delete site volume
```

The whole site (hosts, history, configuration) lives in the named
Docker volume `checkmk`, so it survives restarts and updates.

## Using this folder as a template

This folder is self-contained: copy it out of this template repo to use
it on its own (or clone this repo with sparse-checkout). `.env` is
git-ignored.

```bash
cp -r checkmk ~/my-checkmk && cd ~/my-checkmk
git init
git add .
git commit -m "Initial checkmk setup"
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

Restore data from a backup by restoring the `checkmk` Docker volume on
the target server and running `./run.sh`.

## Health / reverse proxy

It is deployed behind Caddy for HTTPS rather than hitting
`http://server:8072` directly. With Caddyfile:

```caddyfile
checkmk.domain.dev {
	import basic-auth
	reverse_proxy checkmk:5000
}
```

(Caddy runs with host networking and proxies to the host-mapped port
`localhost:8072`. `import basic-auth` is the default gate for every site —
browser login before the app's own login; optionally add
`import tailscale-only` for a tailnet allowlist on top. See `../caddy/Caddyfile`.)
