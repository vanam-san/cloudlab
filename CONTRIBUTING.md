# Contributing to cloudlab

Thanks for helping out. This repo is a collection of independent service
deployments; keep them that way.

## Ground rules

1. **One folder per service, fully standalone.** Anyone should be able to
   copy a single folder (or sparse-checkout it) onto a fresh VPS and run
   it without anything else from this repo — except Caddy, which is
   optional and only needed for production domains.
2. **One command to run, one to update.** Every service folder must have:
   - `run.sh` — idempotent: creates `.env`, pulls, starts, waits until ready.
   - `update.sh` — follows the app's official update docs (link them in a
     header comment), waits until the service is back.
   - `stop.sh` / `restart.sh` — same conventions (wait until back on restart).
   - `README.md` — what it is, quick start, updating, production domain,
     common commands, plus a "Using this folder as a template" section.
   - `.env.example` + `.gitignore` (always ignore `.env`).
   - All `*.sh` executable (`chmod +x`).
3. **Localhost by default.** Backends bind `127.0.0.1:<port>`. Never expose
   an app port publicly from compose; production access goes through Caddy.
   Before picking a port, check it doesn't clash with the table in
   [README.md](README.md).
4. **Explain deviations in comments.** If you work around an upstream quirk
   (dead image registry, missing health endpoint, IPv6 `localhost` pitfall),
   leave a short comment saying what and why, with a link.
5. **Verify by running.** Don't submit a service you haven't started with
   `./run.sh` and updated with `./update.sh` on a real machine. Paste the
   resulting `docker compose ps` output in your PR. At minimum, check
   `bash -n *.sh`, `docker compose config`, and `shellcheck *.sh` if
   available. New folders must be executable (`chmod +x *.sh`) and must
   keep template placeholders (no real domains, IPs, or passwords).
6. **Template hygiene.** This repo is a template: never commit `.env`,
   `plane-app/`, real domains,    tailnet IPs, or "running/paired" instance
   state. Use `example.com` placeholders.

## Adding a service

1. Create `<service>/` with the files listed above (copy `glance/` as the
   simplest template).
2. If upstream ships its own installer/compose (like Plane's `setup.sh`),
   wrap it — don't fork it. Keep upstream files pristine except for minimal,
   commented compatibility fixes.
3. Add the service to the table in [README.md](README.md) and, if it should
   get a production domain, a commented block in [caddy/Caddyfile](caddy/Caddyfile).
4. Secrets go in `.env` (git-ignored). Shared config that users are meant to
   edit (dashboards, Caddyfile) gets committed — say so in the README.

## Updating a service

- Prefer the app's documented update path; encode it in `update.sh`.
- Never wipe volumes in update scripts (`down -v` is for humans, typed
  deliberately).
- After updating, confirm the old data is still there (log in, check).

## Reporting issues

Include: service folder, exact command run, full output, `docker compose ps`,
and relevant `docker compose logs`. Redact secrets from `.env` excerpts.