# Data Persistence

Prism Launcher data should live under `/home/retro` so it survives container recreation via Wolf profile mounts.

## Important Paths

| Path | Purpose | Persists |
| --- | --- | --- |
| `/home/retro/.local/share/PrismLauncher/` | instances, mods, saves | Yes |
| `/home/retro/.config/PrismLauncher/` | launcher settings, accounts | Yes |
| `/opt/prismlauncher/` | launcher binary in image | No |
| `/tmp/` | temporary files | No |

## Backup

Example host-side backup:

```bash
sudo tar -czvf prism-backup-$(date +%Y%m%d).tar.gz \
  /etc/wolf/profile_data/{profile_id}/Prism_Launcher/
```

At minimum, back up:

- `.local/share/PrismLauncher/instances/`
- `.config/PrismLauncher/accounts.json`
- `.config/PrismLauncher/prismlauncher.cfg`

## Restore

```bash
sudo tar -xzvf prism-backup.tar.gz -C /etc/wolf/profile_data/{profile_id}/Prism_Launcher/
```

## Verify

Run:

```bash
./tests/smoke-persistence.sh
```

The script checks write/read persistence across container recreation.
