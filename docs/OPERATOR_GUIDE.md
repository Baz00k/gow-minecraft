# Operator Guide

This guide covers everything you need to run the GoW Prism Launcher container with Wolf.

## Before You Start

**Read [LEGAL.md](../LEGAL.md) first.** Key points:

- You must own a legitimate Minecraft license for gameplay
- Offline profiles work for LAN play or servers with `online-mode=false`
- This project does not bypass Mojang/Microsoft authentication
- TLauncher and SKLauncher are forbidden due to security concerns

---

## Prerequisites

### For NVIDIA Hosts

**Required software on your host machine:**

1. **NVIDIA Driver**

    Install the proprietary NVIDIA driver (version 535 or newer recommended).

    ```bash
    # Ubuntu/Debian
    sudo apt install nvidia-driver-535

    # Verify installation
    nvidia-smi
    ```

2. **NVIDIA Container Toolkit**

    This allows Docker containers to access your GPU.

    ```bash
    # Ubuntu/Debian
    curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
    curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
      sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
      sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

    sudo apt update
    sudo apt install nvidia-container-toolkit

    # Configure Docker to use NVIDIA runtime
    sudo nvidia-ctk runtime configure --runtime=docker
    sudo systemctl restart docker
    ```

3. **Verify GPU Access**

    ```bash
    # Should list your GPU
    docker run --rm --gpus all nvidia/cuda:12.0-base-ubuntu22.04 nvidia-smi
    ```

**Required device nodes:**

- `/dev/nvidia*` - NVIDIA GPU devices
- `/dev/dri/*` - DRM/KMS for display
- `/dev/input/event*` - Input devices

---

### For AMD/Intel Hosts

**Required software on your host machine:**

1. **GPU Drivers**

    AMD and Intel GPUs use Mesa drivers, typically pre-installed on most Linux distributions.

    ```bash
    # Verify AMD driver is loaded
    lsmod | grep amdgpu

    # Verify Intel driver is loaded
    lsmod | grep i915
    ```

2. **Verify Device Nodes**

    ```bash
    # Should show renderD* devices
    ls -la /dev/dri/

    # Example output:
    # crw-rw---- 1 root render 226, 128 Feb 25 10:00 renderD128
    # crw-rw---- 1 root render 226, 129 Feb 25 10:00 renderD129
    ```

3. **User Permissions**

    Ensure your user is in the `render` and `video` groups:

    ```bash
    sudo usermod -aG render,video $USER
    # Log out and back in for changes to take effect
    ```

**Required device nodes:**

- `/dev/dri/renderD*` - GPU render nodes
- `/dev/dri/card*` - DRM devices (optional)
- `/dev/input/event*` - Input devices

**Multiple GPU selection:**

If you have multiple GPUs, check which driver owns each:

```bash
ls -l /sys/class/drm/renderD*/device/driver
```

Use the `WOLF_RENDER_NODE` environment variable in your Wolf config to select a specific GPU (default: `/dev/dri/renderD128`).

---

## Wolf Integration

Wolf handles the streaming layer that lets you access Prism Launcher remotely. You'll add the Prism app to your Wolf configuration.

### Step 1: Install Wolf

Follow the [Wolf quickstart guide](https://games-on-whales.github.io/wolf/stable/user/quickstart.html) to install Wolf on your host.

### Step 2: Pull the Image

```bash
# Replace YOUR-USER with your GitHub username or organization
docker pull ghcr.io/YOUR-USER/gow-prism-offline:latest
```

### Step 3: Add App Configuration

Edit your Wolf configuration file (typically `/etc/wolf/cfg/config.toml`) and add the appropriate app block below.

#### NVIDIA Configuration

```toml
[[profiles.apps]]
title = "Prism Launcher (Offline)"
start_virtual_compositor = true

[profiles.apps.runner]
type = "docker"
name = "WolfPrismOffline"
# Replace YOUR-USER with your GitHub username or organization
image = "ghcr.io/YOUR-USER/gow-prism-offline:latest"

env = [
    "RUN_SWAY=1",
    "GOW_REQUIRED_DEVICES=/dev/input/event* /dev/dri/* /dev/nvidia*",
]

mounts = []
devices = []
ports = []

base_create_json = '''
{
  "HostConfig": {
    "IpcMode": "host",
    "CapAdd": ["NET_RAW", "MKNOD", "NET_ADMIN", "SYS_ADMIN", "SYS_NICE"],
    "Privileged": false,
    "DeviceCgroupRules": [
      "c 13:* rmw",
      "c 244:* rmw"
    ]
  }
}
'''
```

#### AMD/Intel Configuration

```toml
[[profiles.apps]]
title = "Prism Launcher (Offline)"
start_virtual_compositor = true

[profiles.apps.runner]
type = "docker"
name = "WolfPrismOffline"
# Replace YOUR-USER with your GitHub username or organization
image = "ghcr.io/YOUR-USER/gow-prism-offline:latest"

env = [
    "RUN_SWAY=1",
    "GOW_REQUIRED_DEVICES=/dev/input/event* /dev/dri/*",
]

mounts = []
devices = []
ports = []

base_create_json = '''
{
  "HostConfig": {
    "IpcMode": "host",
    "CapAdd": ["NET_RAW", "MKNOD", "NET_ADMIN", "SYS_ADMIN", "SYS_NICE"],
    "Privileged": false,
    "DeviceCgroupRules": [
      "c 13:* rmw"
    ]
  }
}
'''
```

### Step 4: Restart Wolf

```bash
sudo systemctl restart wolf
```

### Configuration Notes

| Setting                           | Purpose                                       |
| --------------------------------- | --------------------------------------------- |
| `start_virtual_compositor = true` | Enables Sway Wayland compositor for the GUI   |
| `RUN_SWAY=1`                      | Tells the container to start the compositor   |
| `GOW_REQUIRED_DEVICES`            | Device paths Wolf probes at container startup |
| `DeviceCgroupRules c 13:*`        | Input devices (`/dev/input/event*`)           |
| `DeviceCgroupRules c 244:*`       | NVIDIA devices (NVIDIA config only)           |

---

## Quick Start

### What You'll Need

- Wolf installed and running
- A Moonlight client (Windows, macOS, Linux, Android, iOS)
- The container image available

### Step-by-Step

1. **Verify Wolf is running**

    ```bash
    sudo systemctl status wolf
    ```

2. **Pair your Moonlight client**
    - Open Moonlight on your client device
    - Add your host's IP address
    - Enter the PIN shown on the host

3. **Launch Prism Launcher**
    - Connect via Moonlight
    - Select "Prism Launcher (Offline)" from your app list
    - The Prism Launcher window appears

4. **First-time setup happens inside the stream**

    See [First-Time Setup](#first-time-setup) below.

---

## First-Time Setup

When you launch Prism Launcher for the first time, you'll see the setup wizard through your Moonlight stream.

### Initial Configuration

1. **Language Selection** - Choose your preferred language

2. **Java Detection** - Prism automatically detects the installed Java versions:
    - Java 21 for Minecraft 1.21+
    - Java 17 for Minecraft 1.18-1.20.4
    - Java 8 for Minecraft 1.16 and below

3. **Account Setup** - Create an offline/local profile:
    - Click "Add Account" or go to Accounts menu
    - Select "Offline" or "Local" account type
    - Enter your desired username (this appears in-game)
    - No Microsoft login required

### Installing Minecraft

1. **Create an Instance**
    - Click "Create New Instance"
    - Choose a Minecraft version
    - Select mod loader if desired (Fabric, Forge, etc.)

2. **Download Game Files**
    - Prism downloads the game files automatically
    - This happens inside the container

3. **Launch and Play**
    - Double-click your instance
    - Minecraft launches inside the stream

### Where Your Data Lives

Wolf persists your Prism data at:

```
/etc/wolf/profile_data/{profile_id}/Prism Launcher (Offline)/
```

This maps to `/home/retro` inside the container. Your instances, saves, and settings survive container restarts.

---

## Building from Source

If you want to build the image yourself instead of pulling from GHCR:

### Prerequisites

- Docker with BuildKit support
- Git

### Build Commands

```bash
# Clone the repository
git clone https://github.com/YOUR-USER/gow-prism-offline.git
cd gow-prism-offline

# Build the image
docker build \
  --build-arg BASE_APP_IMAGE=ghcr.io/games-on-whales/base-app:edge \
  -t gow-prism-offline:local \
  -f build/Dockerfile \
  .

# Verify the build
docker run --rm gow-prism-offline:local java -version
```

### Build Arguments

| Argument                 | Default                                 | Description            |
| ------------------------ | --------------------------------------- | ---------------------- |
| `BASE_APP_IMAGE`         | `ghcr.io/games-on-whales/base-app:edge` | GoW base image         |
| `PRISM_LAUNCHER_VERSION` | `10.0.5`                                | Prism Launcher version |
| `IMAGE_VERSION`          | `dev`                                   | Image version label    |

### Architecture Support

The Dockerfile supports both `amd64` (x86_64) and `arm64` (aarch64) architectures. Docker BuildKit automatically selects the correct AppImage based on `TARGETARCH`.

---

## Troubleshooting

### GPU Not Detected

**Symptoms:**

- Container starts but Minecraft has poor performance
- Errors about missing GPU or fallback to software rendering

**NVIDIA Solutions:**

```bash
# Check NVIDIA driver
nvidia-smi

# Verify container toolkit
docker run --rm --gpus all nvidia/cuda:12.0-base-ubuntu22.04 nvidia-smi

# Check device nodes exist
ls -la /dev/nvidia*
```

**AMD/Intel Solutions:**

```bash
# Check render nodes exist
ls -la /dev/dri/renderD*

# Verify driver is loaded
lsmod | grep -E "amdgpu|i915"

# Check user permissions
groups $USER
# Should include 'render' and 'video'
```

### Container Fails to Start

**Symptoms:**

- Wolf shows "Starting..." then fails
- No window appears in Moonlight

**Solutions:**

1. **Check container logs:**

    ```bash
    docker logs WolfPrismOffline-*
    ```

2. **Verify image exists:**

    ```bash
    docker images | grep gow-prism-offline
    ```

3. **Check Wolf logs:**

    ```bash
    journalctl -u wolf -f
    ```

4. **Verify config syntax:**

    ```bash
    # TOML syntax check (requires python3-toml)
    python3 -c "import toml; toml.load('/etc/wolf/cfg/config.toml')"
    ```

### No Audio

**Symptoms:**

- Video works but no sound

**Solutions:**

Wolf handles audio streaming automatically. If audio is missing:

1. Check Wolf's audio configuration
2. Verify PulseAudio/PipeWire is running on the host
3. Check container logs for audio device errors

### Input Not Working

**Symptoms:**

- Mouse/keyboard doesn't respond in the stream

**Solutions:**

1. **Verify input devices:**

    ```bash
    ls -la /dev/input/event*
    ```

2. **Check uinput module:**

    ```bash
    lsmod | grep uinput
    # If not loaded:
    sudo modprobe uinput
    ```

3. **Verify DeviceCgroupRules** includes `c 13:* rmw` in your Wolf config

### Java Version Issues

**Symptoms:**

- Minecraft fails to launch with Java errors
- "Unsupported class file version" errors

**Solutions:**

Prism Launcher auto-detects installed Java versions. If issues occur:

1. **Check Java in container:**

    ```bash
    docker run --rm gow-prism-offline:local java -version
    ```

2. **Manual Java selection in Prism:**
    - Go to Settings > Java
    - Manually select the correct Java path for your Minecraft version

### Data Not Persisting

**Symptoms:**

- Instances disappear after container restart

**Solutions:**

1. **Check Wolf profile data:**

    ```bash
    ls -la /etc/wolf/profile_data/
    ```

2. **Verify mounts** in Wolf config aren't overriding `/home/retro`

### Performance Issues

**Symptoms:**

- Low FPS
- Stuttering or lag

**Solutions:**

1. **Check GPU utilization:**

    ```bash
    # NVIDIA
    nvidia-smi -l 1

    # AMD
    watch -n 1 'cat /sys/class/drm/card*/device/gpu_busy_percent'
    ```

2. **Adjust Wolf streaming settings:**
    - Lower resolution or bitrate in Moonlight settings
    - Try different encoder (NVENC vs VAAPI)

3. **Check host resource usage:**

    ```bash
    htop
    ```

---

## Getting Help

- **Wolf Documentation:** https://games-on-whales.github.io/wolf/stable/
- **Prism Launcher Wiki:** https://prismlauncher.org/wiki/
- **GitHub Issues:** Report bugs on the project repository

When reporting issues, include:

1. Wolf version (`wolf --version`)
2. Docker version (`docker --version`)
3. GPU and driver version
4. Container logs (`docker logs WolfPrismOffline-*`)
5. Wolf logs (`journalctl -u wolf`)
