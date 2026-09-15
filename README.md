# cloudlab

Self-hosted services on a single VPS. Each folder is a standalone deployment:
clone it anywhere, run one command, get a working app.

## Architecture

All backends join the shared **`cloudlab-proxy` Docker network**. [Caddy](caddy/) is the only
service exposed to the network (ports 80/443) and gives each app a production
domain with automatic HTTPS when you're ready. Localhost port bindings are
kept for direct local access, but Caddy always proxies over the shared
Docker network via container DNS names — never via host ports.

```
internet ──▶ Caddy (:80/:443, auto-TLS) ──▶ app-name:internal-port ──▶ app (cloudlab-proxy network)
                                     └──▶ 127.0.0.1:PORT (direct local access, bypasses Caddy)
```

## Services

| Folder | App | Local URL | Production domain (via Caddy) | Status |
|---|---|---|---|---|
| [umami/](umami/) | Web analytics | http://localhost:3000 | `analytics.example.com` | running |
| [beszel/](beszel/) | Server monitoring (hub + agent) | http://localhost:8090 | `monitor.example.com` | running, VPS paired |
| [glance/](glance/) | Dashboard | http://localhost:8080 | `glance.example.com` | running |
| [actual/](actual/) | Finance manager | http://localhost:5006 | `actual.example.com` | running |
| [caddy/](caddy/) | Reverse proxy | — (ports 80/443) | — | running |
| [plane/](plane/) | Project management | http://localhost:9080 | `plane.example.com` | not started yet |

## Requirements

- A Linux VPS (or any machine) with [Docker Engine](https://docs.docker.com/engine/install/)
  and Docker Compose v2 (`docker compose version`).
- Ports 80 and 443 free if you run Caddy.

## Usage

Each service folder works the same way.

**Start / install (one command):**

```bash
cd <service>   # e.g. cd umami
./run.sh
```

`run.sh` creates `.env` from `.env.example` (generating secrets where the app
needs them), pulls the images, starts the stack, and waits until it answers.
It is idempotent — safe to re-run any time.

**Update (one command, per upstream docs):**

```bash
cd <service>
./update.sh
```

Each `update.sh` follows that app's official update procedure (linked at the
top of the script) and waits until the service is back.

**Other common commands** (run inside the service folder):

```bash
docker compose ps            # status
docker compose logs -f       # logs (add a service name to filter)
docker compose down          # stop (data is kept in Docker volumes)
docker compose down -v       # stop AND delete data volumes
```

## Going to production (domains + HTTPS)

1. Point each domain's DNS (A/AAAA record) at the VPS.
2. Uncomment the matching block in [caddy/Caddyfile](caddy/Caddyfile) and set
   your real domain.
3. Reload Caddy without downtime:

```bash
cd caddy
docker compose exec caddy caddy reload --config /etc/caddy/Caddyfile --adapter caddyfile
```

Caddy obtains and renews certificates automatically. Some apps need to know
their public URL — each service README has a "Production domain" section
(e.g. Plane needs `WEB_URL`/`CORS_ALLOWED_ORIGINS`, Beszel needs `APP_URL`).

## Secrets

Every service keeps runtime secrets in its own `.env`, created from the
committed `.env.example`. `.env` files are git-ignored in every folder —
never commit them. Config that is meant to be shared (e.g. Glance's dashboard,
Caddy's Caddyfile) is committed on purpose; each README calls this out.

## Backups

Data lives in named Docker volumes (and `plane-app/` for Plane), so it
survives restarts, updates, and `git clone` redeploys. Volume names and
app-specific backup tools are documented per service:

- Umami: `umami-db` volume (plus an `ANALYZE;` tip after major upgrades).
- Beszel: `beszel-data` volume; pairing survives updates.
- Actual: `actual-data` volume (`server-files/` + `user-files/` inside).
- Plane: `plane-app/` dir + volumes; `./setup.sh backup` for full backups.
- Caddy: `caddy-data` (certificates), `caddy-config`.
- Glance: stateless; the config in `glance/config/` is the backup.

## Repository layout

```
cloudlab/
├── README.md / CONTRIBUTING.md / CODE_OF_CONDUCT.md / LICENSE
├── caddy/     # reverse proxy (public entry point)
├── umami/     # analytics
├── beszel/    # monitoring
├── glance/    # dashboard (config/ is the dashboard)
├── actual/    # finance
└── plane/     # project management (upstream setup.sh based)
```

Each service folder contains `compose.yml` (or upstream equivalent),
`.env.example`, `.gitignore`, `run.sh`, `update.sh`, and `README.md` with
service-specific instructions. Folders are independent — deploy one, some,
or all.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Be nice — see
[CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md).

## License

MIT — see [LICENSE](LICENSE).