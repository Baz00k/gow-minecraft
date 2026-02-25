# Operator Guide

This guide covers setup and day-to-day operation of the Prism Launcher image with Wolf.

## Before You Start

Read [LEGAL.md](../LEGAL.md).

## Prerequisites

- Wolf installed and running
- Docker installed on the host
- A compatible GPU setup:
  - NVIDIA: drivers + NVIDIA container support
  - AMD/Intel: `/dev/dri/*` devices available

## Configure Wolf

Use one of the templates in `config/`:

- `config/wolf-nvidia.config.toml`
- `config/wolf-amd.config.toml`

Copy the app block into your Wolf `config.toml`, then set the image to your published tag.

## Run

1. Pull image:

   ```bash
   docker pull ghcr.io/YOUR-USER/gow-prism-offline:latest
   ```

2. Restart Wolf:

   ```bash
   sudo systemctl restart wolf
   ```

3. Connect with Moonlight and launch **Prism Launcher (Offline)**.

## Data and Persistence

- User data is expected under `/home/retro` in the container.
- Wolf profile data mount keeps instances, configs, and saves across sessions.
- See [PERSISTENCE.md](./PERSISTENCE.md) for backup/restore details.

## Troubleshooting

- App does not appear in Moonlight: verify Wolf config and restart Wolf.
- Black screen or no render: verify required GPU devices for your host.
- Data missing after restart: confirm Wolf profile data mount is active.

## Validation

Run smoke tests locally:

```bash
./tests/run-all-smoke.sh
```

Results are written to `test-results/evidence/`.
