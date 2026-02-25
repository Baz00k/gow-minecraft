# Data Persistence Guide

This document explains how data persistence works with the GoW Prism Launcher container image when deployed via Wolf.

## Overview

Wolf manages persistence by mounting host storage to the container's `/home/retro` directory. Any data written inside `/home/retro` survives container recreation, while data written elsewhere is lost when the container is removed.

## Prism Launcher Data Paths

Prism Launcher follows the XDG Base Directory Specification. Within the container, data is stored at:

| Path                                      | Contents                            | Persists?                  |
| ----------------------------------------- | ----------------------------------- | -------------------------- |
| `/home/retro/.local/share/PrismLauncher/` | Instances, mods, saves, screenshots | ✅ Yes                     |
| `/home/retro/.config/PrismLauncher/`      | Launcher settings, account configs  | ✅ Yes                     |
| `/home/retro/.cache/PrismLauncher/`       | Temporary cache files               | ✅ Yes (but non-critical)  |
| `/opt/prismlauncher/`                     | Launcher binary (AppImage)          | ❌ No (rebuilt from image) |
| `/tmp/`                                   | Temporary files                     | ❌ No                      |

### Key Subdirectories

Inside `/home/retro/.local/share/PrismLauncher/`:

```
PrismLauncher/
├── instances/           # Minecraft instances (modded, vanilla, etc.)
│   └── <instance-name>/
│       ├── .minecraft/  # Game files
│       │   ├── saves/   # World saves
│       │   ├── mods/    # Mods
│       │   └── ...
│       └── instance.cfg # Instance configuration
├── icons/               # Instance icons
├── themes/              # Custom themes
└── metacache/           # Metadata cache
```

Inside `/home/retro/.config/PrismLauncher/`:

```
PrismLauncher/
├── prismlauncher.cfg    # Main launcher configuration
├── accounts.json        # Account data (offline accounts)
└── themes/              # Theme preferences
```

## Wolf Persistence Model

Wolf automatically creates a dedicated folder structure for each app instance:

```
/etc/wolf/profile_data/{profile_id}/{app_title}/
```

This folder is mounted as `/home/retro` inside the container. The exact host path depends on your Wolf configuration.

### Example

For a profile with ID `default` and app title `Prism Launcher`:

```
Host: /etc/wolf/profile_data/default/Prism_Launcher/
Container: /home/retro/
```

All data written to `/home/retro` inside the container is actually written to the host path above.

## What Persists

✅ **Data that survives container recreation:**

- Minecraft instances (in `.local/share/PrismLauncher/instances/`)
- World saves (in instance `.minecraft/saves/`)
- Installed mods (in instance `.minecraft/mods/`)
- Launcher configuration (in `.config/PrismLauncher/`)
- Offline account profiles (in `.config/PrismLauncher/accounts.json`)
- Screenshots (in instance `.minecraft/screenshots/`)
- Resource packs and shader packs
- Custom themes and icons

## What Does NOT Persist

❌ **Data lost when container is recreated:**

- Container-level changes outside `/home/retro`
- Installed packages (use Dockerfile for permanent installs)
- Environment variable changes (configure via Wolf app config)
- Modified system configuration files
- Temporary files in `/tmp`

## Backup and Restore

### Backup

To backup your Prism Launcher data:

```bash
# Option 1: Backup the Wolf profile data directly (on host)
sudo tar -czvf prism-backup-$(date +%Y%m%d).tar.gz \
    /etc/wolf/profile_data/{profile_id}/Prism_Launcher/

# Option 2: Backup via Docker (if container is running)
docker exec {container_name} tar -czvf /tmp/backup.tar.gz \
    -C /home/retro .local/share/PrismLauncher .config/PrismLauncher
docker cp {container_name}:/tmp/backup.tar.gz ./prism-backup.tar.gz
```

### Restore

To restore from backup:

```bash
# Option 1: Restore to Wolf profile data (on host, stop Wolf first)
sudo tar -xzvf prism-backup.tar.gz -C /etc/wolf/profile_data/{profile_id}/Prism_Launcher/

# Option 2: Restore via Docker
docker cp prism-backup.tar.gz {container_name}:/tmp/
docker exec {container_name} tar -xzvf /tmp/backup.tar.gz -C /home/retro/
```

### Critical Files to Backup

At minimum, backup these paths:

1. `.local/share/PrismLauncher/instances/` — All your Minecraft instances
2. `.config/PrismLauncher/accounts.json` — Your offline account(s)
3. `.config/PrismLauncher/prismlauncher.cfg` — Launcher settings

## Verification

The smoke test `tests/smoke-persistence.sh` verifies that:

1. Data written to `/home/retro` via volume mount persists
2. Data survives container stop/remove/recreate cycle
3. User `retro` has write permissions in `/home/retro`

Run the test locally:

```bash
./tests/smoke-persistence.sh
```

## Troubleshooting

### Data Not Persisting

1. **Verify Wolf mount**: Check that Wolf is configured to mount profile data
2. **Check permissions**: Ensure the container runs as user `retro` (UID inherited from base-app)
3. **Verify path**: Ensure Prism is writing to `/home/retro`, not `/root` or other paths

### Restoring to New Wolf Profile

When migrating to a new profile or host:

1. Create the new profile in Wolf
2. Start the app once to create the directory structure
3. Stop Wolf
4. Extract backup to the new profile path
5. Start Wolf

### Instance-Specific Backup

To backup only specific instances:

```bash
# Backup specific instance
docker exec {container_name} tar -czvf /tmp/instance-backup.tar.gz \
    -C /home/retro/.local/share/PrismLauncher/instances/{instance_name} .

# Restore specific instance
docker cp instance-backup.tar.gz {container_name}:/tmp/
docker exec {container_name} mkdir -p /home/retro/.local/share/PrismLauncher/instances/{instance_name}
docker exec {container_name} tar -xzvf /tmp/instance-backup.tar.gz \
    -C /home/retro/.local/share/PrismLauncher/instances/{instance_name}
```

## References

- [Wolf Configuration - Data Setup](https://games-on-whales.github.io/wolf/stable/user/configuration.html#data_setup)
- [XDG Base Directory Specification](https://specifications.freedesktop.org/basedir-spec/basedir-spec-latest.html)
- [Prism Launcher Documentation](https://prismlauncher.org/wiki/)
