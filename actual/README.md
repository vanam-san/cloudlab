# Actual Budget on VPS

Self-hosted [Actual Budget](https://actualbudget.org/) (personal finance
manager) using the official `actualbudget/actual-server:latest` image,
deployed with Docker Compose.

The `compose.yml` here follows
[upstream's Docker Compose method](https://actualbudget.org/docs/install/docker)
with small local adaptations (localhost-only port, parameterized image,
named volume, shared proxy network).

## Quick start (one command)

Requires Docker + Docker Compose on the server.

```bash
./run.sh
```

That one command:

1. Creates `.env` from `.env.example` (if missing)
2. Pulls the latest image
3. Starts the server on localhost:5006 and waits until ready

Open the printed URL and set the server password in the UI on first run.

`.env` is git-ignored; secrets are never committed.

## Updating

Per upstream docs
([Docker](https://actualbudget.org/docs/install/docker),
"Update Docker Compose container"):

```bash
./update.sh
```

It pulls the latest image and recreates the container (`down` + `up -d`,
as the docs prescribe). Data in the `actual-data` volume is preserved.

Switch `ACTUAL_IMAGE` between `:latest` (releases, default) and
`:nightly` (bleeding edge, may have bugs — keep backups) in `.env` to
change which updates you receive.

## Production domain

In production Actual Budget gets a domain via Caddy (see `../caddy`).
Upstream documents this exact setup
([Using a Reverse Proxy](https://actualbudget.org/docs/config/reverse-proxies)):

```caddyfile
actual.example.com {
	import tailscale-only
	reverse_proxy actual:5006
}
```

(`import tailscale-only` restricts the site to tailnet clients; see
`../caddy/Caddyfile`. Glance is the only site without it.)

No extra app config is needed — Caddy terminates HTTPS automatically.

## Common commands

```bash
./run.sh                         # first start / recreate everything
./update.sh                      # update app (data volume untouched)
docker compose logs -f actual
docker compose down              # stop (keeps data)
docker compose down -v           # stop + delete budget data
```

Data lives in the named Docker volume (`actual-data`, mounted as `/data`
with `server-files/` + `user-files/` inside), so it survives restarts and
updates.

## Pushing to GitHub

This folder is a standalone git repository. `.env` is git-ignored.

```bash
git init
git add .
git commit -m "Initial actual setup"
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
