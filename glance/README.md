# Glance on VPS

[Glance](https://github.com/glanceapp/glance) self-hosted dashboard using
the official `glanceapp/glance:latest` image, deployed with Docker Compose.

## Quick start (one command)

Requires Docker + Docker Compose on the server.

```bash
./run.sh
```

That one command:

1. Creates `.env` from `.env.example` (if missing)
2. Pulls the latest Glance image
3. Starts the dashboard on localhost:8080 and waits until ready

Unlike the other services here, the dashboard config (`config/glance.yml`)
IS committed to git — customizing it is the point. Edit it, then apply:

```bash
docker compose restart glance
```

Widget reference:
[configuration.md](https://github.com/glanceapp/glance/blob/main/docs/configuration.md).

## Updating

```bash
./update.sh
```

It pulls the latest image and recreates the container. Your dashboard
config in `./config` is a bind mount and is untouched by the update.

## Production domain

In production Glance gets a domain via Caddy (see `../caddy`):

```caddyfile
glance.example.com {
	reverse_proxy host.docker.internal:8080
}
```

Then update the bookmark URLs in `config/glance.yml` from `localhost`
to the production domains.

## Common commands

```bash
./run.sh                         # pull latest + (re)start
./update.sh                      # update Glance, config untouched
docker compose logs glance       # usually a config error if it won't start
docker compose restart glance    # apply config/glance.yml changes
docker compose down              # stop (config stays in ./config)
```

## Pushing to GitHub

This folder is a standalone git repository. `.env` is git-ignored, but
`config/glance.yml` is committed on purpose.

```bash
git init
git add .
git commit -m "Initial glance setup"
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