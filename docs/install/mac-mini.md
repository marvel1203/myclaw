---
summary: "Deploy OpenClaw from a current repo checkout to a dedicated Mac mini"
read_when:
  - You want to run OpenClaw or a fork on a Mac mini
  - You want a dedicated always-on macOS host
title: "Mac mini"
---

# Deploy OpenClaw on a Mac mini

Yes - a current OpenClaw repo checkout can be deployed on a Mac mini.

This is a good fit when you want:

- a dedicated always-on macOS host
- local launchd supervision instead of a terminal session
- optional macOS-only capabilities later (notifications, Accessibility, screen capture, camera, `system.run` via the macOS app/node flow)

For a dedicated Mac mini, the simplest path is usually **CLI + launchd service**. Install the macOS app only if you also need the companion app UI or macOS node features.

## What works today

- The Gateway is supported on macOS.
- `openclaw gateway install` installs a per-user LaunchAgent.
- `openclaw onboard --install-daemon` can configure auth and install the service in one flow.
- You can manage the box remotely over SSH or Tailscale.

## Recommended deployment shape

Use this when the Mac mini is your personal always-on host:

1. Keep one repo checkout on the Mac mini.
2. Build the CLI from source.
3. Link the CLI globally.
4. Run onboarding once with `--install-daemon`.
5. Use `openclaw gateway status` and `openclaw health` for checks.

## Prerequisites

- macOS on the Mac mini
- Node 22+
- `pnpm`
- a login user session for the per-user LaunchAgent
- your model provider credentials

If this is a fresh machine, install Node first, then verify:

```bash
node --version
pnpm --version
```

## 1. Get the latest repo code

If you are starting from scratch, clone your fork or the upstream repo:

```bash
git clone <your-repo-url>
cd <your-repo-dir>
```

If the repo is already present on the Mac mini, update it:

```bash
git checkout main
git pull --rebase origin main
```

If you also track upstream, sync that first and then fast-forward or rebase your fork as needed.

## 2. Install dependencies and build

From the repo root:

```bash
pnpm install
pnpm build
pnpm link --global
```

That makes the built `openclaw` CLI available system-wide for your user.

## 3. Run first-time onboarding

Use the guided setup and install the background service:

```bash
openclaw onboard --install-daemon
```

During onboarding, set up:

- model provider auth
- Gateway auth token or password
- optional channels
- the macOS LaunchAgent service

If you prefer a more manual flow, this also works:

```bash
openclaw gateway install
openclaw configure
```

## 4. Verify the deployment

Run these checks after onboarding:

```bash
openclaw gateway status
openclaw health
openclaw dashboard
```

Healthy baseline:

- `openclaw gateway status` shows the runtime as running
- `openclaw health` returns a valid Gateway health snapshot
- the dashboard opens at the local Gateway URL

If you want channel readiness too:

```bash
openclaw channels status --probe
```

## 5. Log in to channels

If you use WhatsApp or other interactive channels, complete login on the Mac mini itself:

```bash
openclaw channels login
```

Examples:

- WhatsApp QR login should be scanned from the session running on the Mac mini
- Telegram or Discord tokens can be configured during onboarding or in config later

## 6. Keep the Mac mini reliable

For a home or office deployment, also make sure:

- the Mac mini does not sleep unexpectedly
- SSH or Tailscale is enabled for remote access
- the repo checkout, config, and state live on local storage, not cloud-synced folders

Recommended state location:

```bash
OPENCLAW_STATE_DIR=~/.openclaw
```

## 7. Updating later

When you want to deploy the latest repo changes:

```bash
git checkout main
git pull --rebase origin main
pnpm install
pnpm build
pnpm link --global
openclaw gateway restart
```

After updating, re-run:

```bash
openclaw gateway status
openclaw health
```

## CLI-only vs macOS app

For a dedicated Mac mini, **CLI-only** is usually enough.

Install the macOS app as well if you need:

- native menu bar controls
- TCC-managed macOS permissions
- macOS node features such as notifications, screen capture, camera, or `system.run`
- remote-control workflows from another Mac

See [macOS App](/platforms/macos) and [Gateway on macOS](/platforms/mac/bundled-gateway).

## Troubleshooting

### `openclaw` not found

Your global npm or pnpm bin directory is probably missing from `PATH`. See [Install](/install#troubleshooting-openclaw-not-found).

### Gateway service installed but not healthy

Run:

```bash
openclaw gateway status
openclaw doctor
openclaw logs --follow
```

### Port 18789 already in use

Another Gateway or manual process is already listening. Stop the old process or move this instance to another port.

### Need remote browser access

Prefer Tailscale or an SSH tunnel instead of exposing the Gateway directly to the public internet. See [Remote Gateway](/gateway/remote) and [Tailscale](/gateway/tailscale).

## Related docs

- [Getting Started](/start/getting-started)
- [Setup](/start/setup)
- [Gateway runbook](/gateway)
- [macOS App](/platforms/macos)
- [Gateway on macOS](/platforms/mac/bundled-gateway)
