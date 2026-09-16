# Beszel on VPS

[Beszel](https://beszel.dev/) lightweight server monitoring hub, using the
official `henrygd/beszel:latest` image, deployed with Docker Compose.

## Quick start (one command)

Requires Docker + Docker Compose on the server.

```bash
./run.sh
```

That one command:

1. Creates `.env` from `.env.example` (if missing)
2. Pulls the latest Beszel hub image (and the agent image if paired)
3. Starts the hub on localhost:8090 and waits until ready
4. Starts the agent too, if `AGENT_TOKEN`/`AGENT_KEY` are set in `.env`

Open the printed URL and create the admin account in the web UI.

`.env` is git-ignored; the agent tokens live there once paired.

## Monitoring this VPS (agent)

The hub alone shows no systems. The agent service is already defined in
`compose.yml` (unix-socket setup: hub and agent share a socket file, so no
agent ports are published). It stays off until paired:

1. In the hub UI go to Systems -> Add system. Enter
   `/beszel_socket/beszel.sock` as Host / IP, then copy the token and
   public key it generates.
2. Put the secrets in `.env` (git-ignored):

```dotenv
AGENT_TOKEN=<token from the UI>
AGENT_KEY="<public key from the UI>"
```

3. Re-run `./run.sh`. It detects the tokens and starts the agent via the
   `agent` compose profile. Data appears in the hub UI within a minute.

To start/stop the agent manually:

```bash
docker compose --profile agent up -d beszel-agent
docker compose stop beszel-agent
```

See https://beszel.dev/guide/agent-installation for remote systems and
all other agent options.

## Production domain

In production the hub gets a domain via Caddy (see `../caddy`):

```caddyfile
monitor.example.com {
	import tailscale-only
	reverse_proxy beszel:8090
}
```

(Caddy reaches the hub over the shared `cloudlab-proxy` Docker network
via the container DNS name `beszel:8090`. `import tailscale-only`
restricts the site to tailnet clients; see `../caddy/Caddyfile`.)

Then set `APP_URL=https://monitor.example.com` in `.env` and re-run
`./run.sh` (required for agent callbacks and alert links).

## Updating

New hub/agent releases are announced at
[github.com/henrygd/beszel/releases](https://github.com/henrygd/beszel/releases).
To update:

```bash
./update.sh
```

It pulls the latest image(s) and recreates the containers. Hub data,
agent state and the pairing survive in named volumes — no admin
re-creation or re-pairing needed.

## Common commands

```bash
./run.sh            # pull latest + (re)start
./update.sh         # update hub (+ agent if paired)
docker compose logs -f beszel
docker compose down        # stop (keeps data)
docker compose down -v     # stop + delete hub data volume
```

Hub data lives in the named Docker volume `beszel-data`, so it survives
restarts and updates.

## Pushing to GitHub

This folder is a standalone git repository:

```bash
git init
git add .
git commit -m "Initial beszel setup"
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