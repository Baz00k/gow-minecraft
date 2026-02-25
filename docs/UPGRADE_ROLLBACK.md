# Upgrade and Rollback Playbook

**Document Status:** Active  
**Last Updated:** 2026-02-25  
**Applies To:** GoW Prism Launcher Offline-Enabled Docker Image

---

## Overview

This playbook documents controlled procedures for upgrading dependencies and rolling back to known-good states. All upgrades follow a test-first approach to prevent disruptions.

---

## GHCR Package Versioning

Images are published to GitHub Container Registry with the following tag scheme:

| Tag Type | Format | Example | Use Case |
|----------|--------|---------|----------|
| **Latest** | `:latest` | `ghcr.io/USER/gow-prism-offline:latest` | Most recent stable build |
| **Semver** | `:1.0.0` | `ghcr.io/USER/gow-prism-offline:1.2.3` | Pinned release versions |
| **Prerelease** | `:1.0.0-rc.1` | `ghcr.io/USER/gow-prism-offline:1.0.0-rc.1` | Release candidates |
| **Commit SHA** | `:sha-abc123` | `ghcr.io/USER/gow-prism-offline:sha-8f14e45` | Exact build reference |

Rollback typically means switching from `:latest` to a specific semver tag in your Wolf config.

---

## Upgrade Process: Base Image

The base image (`ghcr.io/games-on-whales/base-app`) provides the foundational runtime.

### Step 1: Check Upstream Changelog

```bash
# View recent commits and releases
open https://github.com/games-on-whales/gow/commits/main

# Check for breaking changes in the base-app package
open https://github.com/games-on-whales/gow/pkgs/container/base-app
```

Review for:
- Breaking changes to environment variables
- Changes to device requirements
- Updates to Sway or inputtino configurations
- Security advisories

### Step 2: Fetch New Digest

```bash
# Pull the latest edge tag
docker pull ghcr.io/games-on-whales/base-app:edge

# Get the digest
docker inspect --format='{{index .RepoDigests 0}}' ghcr.io/games-on-whales/base-app:edge

# Or fetch from GitHub UI:
open https://github.com/games-on-whales/gow/pkgs/container/base-app
```

### Step 3: Update pins.env

Edit `build/pins.env`:

```bash
# Update the digest portion only
BASE_APP_IMAGE=ghcr.io/games-on-whales/base-app:edge@sha256:NEW_DIGEST_HERE
```

Also update the "Last verified" comment date.

### Step 4: Build and Test Locally

```bash
# Build with updated pin
docker build \
  --build-arg BASE_APP_IMAGE="$(grep BASE_APP_IMAGE build/pins.env | cut -d= -f2)" \
  -t gow-prism-offline:test \
  -f build/Dockerfile \
  .

# Verify base image was used
docker inspect gow-prism-offline:test | jq '.[0].Config.Labels'

# Run smoke tests (see Testing Checklist below)
docker run --rm -it gow-prism-offline:test java -version
docker run --rm -it gow-prism-offline:test which prismlauncher
```

### Step 5: Create Pull Request

```bash
# Create feature branch
git checkout -b upgrade/base-image-YYYY-MM-DD

# Commit the change
git add build/pins.env
git commit -m "chore: bump base image digest

- Update base-app to digest sha256:NEW_DIGEST
- Reviewed upstream changelog: no breaking changes
- Tested locally: all smoke tests pass"

# Push and create PR
git push -u origin upgrade/base-image-YYYY-MM-DD
gh pr create --title "chore: bump base image digest" --body "..."
```

### Step 6: Verify CI Passes

Monitor the CI pipeline for:
- Build success on both amd64 and arm64
- No new linting errors
- All tests pass

### Step 7: Merge and Tag (if applicable)

```bash
# Merge the PR
gh pr merge --squash

# If this warrants a version bump, tag a release
git tag v1.X.X
git push origin v1.X.X
```

---

## Upgrade Process: Prism Launcher

Prism Launcher version bumps follow upstream releases from Diegiwg/PrismLauncher-Cracked.

### Step 1: Check Upstream Release

```bash
# View releases
open https://github.com/Diegiwg/PrismLauncher-Cracked/releases

# Check what changed
# Look for: new features, bug fixes, security patches
```

### Step 2: Fetch New AppImage Checksums

```bash
# Define the new version
NEW_VERSION="10.0.6"

# Download both AppImages
curl -LO "https://github.com/Diegiwg/PrismLauncher-Cracked/releases/download/${NEW_VERSION}/PrismLauncher-Linux-x86_64.AppImage"
curl -LO "https://github.com/Diegiwg/PrismLauncher-Cracked/releases/download/${NEW_VERSION}/PrismLauncher-Linux-aarch64.AppImage"

# Calculate SHA256 checksums
sha256sum "PrismLauncher-Linux-x86_64.AppImage"
sha256sum "PrismLauncher-Linux-aarch64.AppImage"

# Clean up
rm -f PrismLauncher-Linux-*.AppImage
```

### Step 3: Update pins.env

Edit `build/pins.env`:

```bash
# Update version
PRISM_LAUNCHER_VERSION=10.0.6

# Update URLs and checksums
PRISM_LAUNCHER_APPIMAGE_X86_64_URL=https://github.com/Diegiwg/PrismLauncher-Cracked/releases/download/10.0.6/PrismLauncher-Linux-x86_64.AppImage
PRISM_LAUNCHER_APPIMAGE_X86_64_SHA256=<new-sha256>
PRISM_LAUNCHER_APPIMAGE_AARCH64_URL=https://github.com/Diegiwg/PrismLauncher-Cracked/releases/download/10.0.6/PrismLauncher-Linux-aarch64.AppImage
PRISM_LAUNCHER_APPIMAGE_AARCH64_SHA256=<new-sha256>
```

### Step 4: Build and Test Locally

```bash
# Build with updated version
docker build \
  --build-arg PRISM_LAUNCHER_VERSION="10.0.6" \
  -t gow-prism-offline:test \
  -f build/Dockerfile \
  .

# Verify Prism version
docker run --rm gow-prism-offline:test prismlauncher --version

# Test offline profile creation (manual verification in stream)
# See Testing Checklist below
```

### Step 5: Create Pull Request

```bash
git checkout -b upgrade/prism-10.0.6
git add build/pins.env
git commit -m "feat: bump Prism Launcher to 10.0.6

- Update from 10.0.5 to 10.0.6
- Upstream changelog: https://github.com/Diegiwg/PrismLauncher-Cracked/releases/tag/10.0.6
- SHA256 checksums verified
- Tested locally: offline profile creation works"
git push -u origin upgrade/prism-10.0.6
gh pr create --title "feat: bump Prism Launcher to 10.0.6" --body "..."
```

### Step 6: Merge and Tag

Follow same process as base image upgrade.

---

## Upgrade Process: Java Runtime

Java runtimes are installed via Debian packages. Updates typically come through base image bumps, but you can pin specific versions if needed.

### Standard Update (via Base Image)

Most Java updates are inherited when you bump the base image. No separate action required.

### Explicit Version Pin (if needed)

If you need to pin a specific Java version:

```dockerfile
# In Dockerfile, modify the package installation
RUN apt-get update && apt-get install -y \
    openjdk-21-jre=21.0.3+9-1 \
    openjdk-17-jre=17.0.11+9-1 \
    openjdk-8-jre=8u412-b08-1 \
    && rm -rf /var/lib/apt/lists/*
```

### Verify Java Versions

```bash
# Test each Java version in the built image
docker run --rm gow-prism-offline:test sh -c '
  for v in 8 17 21; do
    echo "Java $v:"
    update-alternatives --list java 2>/dev/null | grep -$v || true
  done
'

# Or test directly
docker run --rm gow-prism-offline:test java -version
```

---

## Rollback Triggers

### Critical Triggers (Immediate Rollback Required)

| Trigger | Action |
|---------|--------|
| Image fails to start | Revert to previous tag immediately |
| Authentication bypass detected | Revert, conduct security review |
| Data loss or corruption | Revert, notify users |
| Critical CVE in pinned version | Revert to known-good, patch |

### Warning Triggers (Investigate First)

| Trigger | Action |
|---------|--------|
| Performance regression > 20% | Profile, assess, potentially rollback |
| New crash reports | Triage severity, patch or rollback |
| Compatibility reports | Investigate, document workaround |
| UI/UX regressions | Assess impact, may wait for patch |

---

## Rollback Process: Revert to Previous Image Tag

This is the fastest rollback method when CI has already published a previous version.

### Step 1: Identify Last Known Good Tag

```bash
# List available tags in GHCR
# Via GitHub UI:
open https://github.com/YOUR-USER/gow-prism-offline/pkgs/container/gow-prism-offline/versions

# Or via gh CLI:
gh api /users/YOUR-USER/packages/container/gow-prism-offline/versions
```

### Step 2: Update Wolf Configuration

Edit your Wolf config (`/etc/wolf/cfg/config.toml`):

```toml
# BEFORE (using latest)
image = "ghcr.io/YOUR-USER/gow-prism-offline:latest"

# AFTER (pinned to known-good version)
image = "ghcr.io/YOUR-USER/gow-prism-offline:1.2.3"
```

### Step 3: Restart Wolf

```bash
sudo systemctl restart wolf
```

### Step 4: Verify Rollback

```bash
# Check which image is running
docker ps | grep gow-prism-offline

# Verify the image digest matches expected version
docker inspect WolfPrismOffline-* | jq '.[0].Config.Image'

# Test functionality through Moonlight stream
```

---

## Rollback Process: Revert pins.env Changes

Use this when you need to rebuild from source with previous pins.

### Step 1: Identify the Revert Commit

```bash
# View pins.env history
git log --oneline build/pins.env

# Find the commit with known-good pins
# Example output:
# abc1234 chore: bump Prism Launcher to 10.0.6
# def5678 chore: bump base image digest
# 9012abc feat: bump Prism Launcher to 10.0.5  <-- known good
```

### Step 2: Revert the Changes

```bash
# Option A: Revert specific commit
git revert abc1234 --no-commit
git commit -m "rollback: revert Prism Launcher to 10.0.5

Trigger: [describe the issue]
Rollback to: 10.0.5 (commit 9012abc)"

# Option B: Checkout specific version of pins.env
git checkout 9012abc -- build/pins.env
git commit -m "rollback: revert pins.env to 10.0.5 state

Trigger: [describe the issue]"
```

### Step 3: Build and Test

```bash
# Build with reverted pins
docker build -t gow-prism-offline:rollback -f build/Dockerfile .

# Run smoke tests
docker run --rm gow-prism-offline:rollback java -version
docker run --rm gow-prism-offline:rollback prismlauncher --version
```

### Step 4: Merge and Verify CI

```bash
git push
gh pr create --title "rollback: revert to known-good pins" --body "..."
```

---

## Testing Checklist

### Pre-Upgrade Tests

Run these on your current working image to establish a baseline:

- [ ] Container starts without errors
- [ ] `java -version` shows expected versions (21, 17, 8)
- [ ] `prismlauncher --version` matches pinned version
- [ ] GPU detection works (check container logs)
- [ ] Sway compositor starts

### Post-Upgrade Tests

Run these on the upgraded image before merging:

**Container Basics:**
- [ ] Image builds without errors
- [ ] Image size is reasonable (no unexpected bloat)
- [ ] Container starts and responds to signals
- [ ] No unexpected warnings in build output

**Java Verification:**
- [ ] `java -version` shows Java 21
- [ ] `java -version` shows Java 17
- [ ] `java -version` shows Java 8
- [ ] All Java versions accessible via alternatives

**Prism Launcher Verification:**
- [ ] `prismlauncher --version` matches new version
- [ ] AppImage checksum verified at build time
- [ ] Symlink to `/usr/local/bin/prismlauncher` works

**Functional Tests (via Moonlight stream):**
- [ ] Prism Launcher window appears
- [ ] Can create offline/local profile
- [ ] Can create new instance
- [ ] Can download Minecraft version
- [ ] Can launch Minecraft instance
- [ ] Game runs with hardware acceleration
- [ ] Input (keyboard/mouse) works
- [ ] Audio works

**Architecture Tests:**
- [ ] amd64 build succeeds
- [ ] arm64 build succeeds
- [ ] Correct AppImage selected per architecture

### Post-Deploy Verification

After deploying to production:

- [ ] Wolf starts the container successfully
- [ ] Users can connect via Moonlight
- [ ] No errors in container logs (`docker logs`)
- [ ] No errors in Wolf logs (`journalctl -u wolf`)
- [ ] Existing instances load correctly
- [ ] New instance creation works

---

## Freeze Periods

During these periods, upgrades require additional approval:

| Period | Duration | Requirement |
|--------|----------|-------------|
| Pre-release | 1 week before tagged release | Maintainer approval |
| Post-incident | 48 hours after production incident | Post-mortem complete |

---

## Emergency Contacts

For critical issues requiring immediate attention:

1. Create a GitHub issue with `critical` label
2. Reference this playbook in the issue
3. Document the trigger and rollback actions taken

---

## Changelog

| Date | Version | Changes |
|------|---------|---------|
| 2026-02-25 | 1.0.0 | Initial playbook document |
