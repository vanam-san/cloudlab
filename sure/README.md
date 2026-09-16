# Sure on VPS

Self-hosted [Sure](https://github.com/we-promise/sure) (personal finance
manager) using the official `ghcr.io/we-promise/sure:stable` image plus
PostgreSQL and Redis, deployed with Docker Compose.

The `compose.yml` here is upstream's example with small local adaptations
(localhost-only port, port 3001, parameterized image — all marked `LOCAL`
in the file).

## Quick start (one command)

Requires Docker + Docker Compose on the server.

```bash
./run.sh
```

That one command:

1. Creates `.env` from `.env.example` (if missing)
2. Generates random `POSTGRES_PASSWORD` / `SECRET_KEY_BASE`
3. Pulls the latest images
4. Starts Sure + Postgres + Redis on localhost:3001 and waits until ready

Open the printed URL and register the admin account, then restrict future
signups under Settings > Self-Hosting > Onboarding (Invite-only or Closed).

`.env` is git-ignored; secrets are never committed.

## Updating

Per upstream docs
([docs/hosting/docker.md](https://github.com/we-promise/sure/blob/main/docs/hosting/docker.md),
"How to update your app"):

```bash
./update.sh
```

It pulls the latest image and restarts sure + worker without touching
db/redis (`--no-deps`), then waits until the app responds again. Switch
`SURE_IMAGE` between `:stable` (releases, default) and `:latest` (alpha)
in `.env` to change which updates you receive.

## Production domain

In production Sure gets a domain via Caddy (see `../caddy`):

```caddyfile
sure.example.com {
	import tailscale-only
	reverse_proxy sure:3000
}
```

(`import tailscale-only` restricts the site to tailnet clients; see
`../caddy/Caddyfile`.)

Because Caddy terminates HTTPS, tell Rails the proxied requests were
originally secure — uncomment in `.env` and re-run `./run.sh`:

```dotenv
RAILS_ASSUME_SSL=true
```

If you use passkeys/security keys (WebAuthn MFA), also pin these in
`.env` to the production domain (see upstream `docs/hosting/webauthn.md`):

```dotenv
WEBAUTHN_RP_ID="example.com"
WEBAUTHN_ALLOWED_ORIGINS="https://sure.example.com"
```

## Common commands

```bash
./run.sh                         # first start / recreate everything
./update.sh                      # update app, db/redis untouched
docker compose logs -f sure worker
docker compose down              # stop (keeps data)
docker compose down -v           # stop + delete db/redis/app volumes
```

Data lives in the named Docker volumes (`postgres-data`, `redis-data`,
`app-storage`), so it survives restarts and updates.

The `backup` profile from upstream is not wired up here (it needs
upstream's `bin/db-backup.sh`); plain `./run.sh` never starts it.

## Pushing to GitHub

This folder is a standalone git repository. `.env` is git-ignored.

```bash
git init
git add .
git commit -m "Initial sure setup"
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