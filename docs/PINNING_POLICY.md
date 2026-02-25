# Source Provenance and Pinning Policy

**Document Status:** Hardened (T8 Complete)  
**Last Updated:** 2026-02-25  
**Applies To:** GoW Prism Launcher Offline-Enabled Docker Image
---

## Purpose

This document defines the policy for how upstream dependencies are referenced, pinned, updated, and verified in the GoW Prism Launcher offline-enabled Docker image. Strict pinning ensures:

- **Reproducibility:** Identical builds produce identical images
- **Security:** Supply chain integrity through digest/commit verification
- **Auditability:** Clear provenance trail for all dependencies
- **Stability:** Predictable behavior across rebuilds

---

## Base Image Pin

### Source

```
ghcr.io/games-on-whales/base-app
```

The `base-app` image provides the foundational runtime environment including:
- Wayland compositor (Sway)
- Input handling (inputtino)
- Audio/video streaming infrastructure
- User environment setup

### Pinning Strategy

| Attribute | Value | Notes |
|-----------|-------|-------|
| **Registry** | `ghcr.io` | GitHub Container Registry |
| **Repository** | `games-on-whales/base-app` | Official GoW image |
| **Tag** | `:edge` | Development build tag |
| **Digest** | `sha256:66cb03a499a78bd81e75aa89eb7b33d5ee679355a8dae24d2989b9fd56e46b04` | Immutable digest pin (T8) |
| **Last Verified** | 2026-02-25 | Fetched from GH package page |
### Initial Pin (T2)

```bash
# Floating tag - acceptable for initial development only
BASE_APP_IMAGE=ghcr.io/games-on-whales/base-app:edge
```

### Hardened Pin (T8 Complete)

```bash
# Immutable digest pin - production ready
# Fetched from: https://github.com/games-on-whales/gow/pkgs/container/base-app
BASE_APP_IMAGE=ghcr.io/games-on-whales/base-app:edge@sha256:66cb03a499a78bd81e75aa89eb7b33d5ee679355a8dae24d2989b9fd56e46b04
```

> **Note:** The digest pin ensures reproducible builds. When updating the base image, 
> fetch the new digest from the GHCR package page and update `build/pins.env`.
### Good vs Bad Examples

**GOOD - Immutable reference:**
```dockerfile
FROM ghcr.io/games-on-whales/base-app:edge@sha256:abc123...
```

**GOOD - Semver tag with digest:**
```dockerfile
FROM ghcr.io/games-on-whales/base-app:1.2.3@sha256:abc123...
```

**BAD - Floating tag only:**
```dockerfile
FROM ghcr.io/games-on-whales/base-app:edge
FROM ghcr.io/games-on-whales/base-app:latest
```

**BAD - No version constraint:**
```dockerfile
FROM ghcr.io/games-on-whales/base-app
```

---

## Launcher Source Pin

### Source Selection Criteria

The offline-enabled Prism Launcher fork must meet ALL criteria:

1. **Open Source:** GPL-3.0 compatible license
2. **Auditable:** Full source code available on GitHub
3. **Minimal Modifications:** Only MSA gate removal, no other changes
4. **Active Maintenance:** Recent commits and releases
5. **Community Trust:** Significant stars/forks indicating adoption
6. **Release Cadence:** Follows upstream Prism Launcher releases

### Candidate: Diegiwg/PrismLauncher-Cracked

| Attribute | Value |
|-----------|-------|
| **URL** | `https://github.com/Diegiwg/PrismLauncher-Cracked` |
| **Stars** | ~1,500+ |
| **Forks** | ~150+ |
| **License** | GPL-3.0 |
| **Modification** | MSA gate check removal only |
| **Latest Release** | 10.0.5 (2026-02-22) |
| **Upstream Sync** | Follows official Prism Launcher releases |

> **Final Selection:** Diegiwg/PrismLauncher-Cracked v10.0.5 confirmed in T7.

### Pinning Strategy

| Pin Type | Format | Use Case |
|----------|--------|----------|
| **Release Tag** | `10.0.5` | Recommended - follows upstream releases |
| **Commit SHA** | `abc123def456...` | Maximum reproducibility, requires manual updates |

### Final Pin (T7)

```bash
PRISM_LAUNCHER_SOURCE=https://github.com/Diegiwg/PrismLauncher-Cracked
PRISM_LAUNCHER_VERSION=10.0.5

# AppImage URLs and SHA256 checksums for reproducible installation
PRISM_LAUNCHER_APPIMAGE_X86_64_URL=https://github.com/Diegiwg/PrismLauncher-Cracked/releases/download/10.0.5/PrismLauncher-Linux-x86_64.AppImage
PRISM_LAUNCHER_APPIMAGE_X86_64_SHA256=8e1eb0e97967fc49cfd28066b0e64d30eaa831cfa311db1cbf81aebdd5f0dbba
PRISM_LAUNCHER_APPIMAGE_AARCH64_URL=https://github.com/Diegiwg/PrismLauncher-Cracked/releases/download/10.0.5/PrismLauncher-Linux-aarch64.AppImage
PRISM_LAUNCHER_APPIMAGE_AARCH64_SHA256=63731437ade51447256837066b349a2f693a8cc147c178658793eac8f4a6d282
```

### Alternative: AUR Package

Arch Linux AUR provides `prismlauncher-offline` package:
- **URL:** `https://aur.archlinux.org/packages/prismlauncher-offline`
- **Version:** 10.0.2-1
- **Builds from:** Diegiwg/PrismLauncher-Cracked source

This may be preferred for Alpine/Arch-based builds.

### Installation Method: AppImage

The chosen installation method uses pre-built AppImages from GitHub releases:

**Why AppImage?**
- **Portability:** Self-contained binary with all dependencies bundled
- **Multi-architecture:** Supports both x86_64 and aarch64
- **Verification:** SHA256 checksums ensure supply chain integrity
- **Simplicity:** No build dependencies, faster CI builds

**Installation Steps:**
1. Download AppImage from GitHub releases based on `TARGETARCH`
2. Verify SHA256 checksum against pinned value
3. Make executable and symlink to `/usr/local/bin/prismlauncher`

**Alternative Methods Considered:**
- **Build from source:** Most reproducible but requires extensive build deps
- **AUR package:** Arch-specific, not suitable for Debian base
- **makedeb repo:** Used by upstream GoW but has reliability issues

### Good vs Bad Examples

**GOOD - Release tag:**
```bash
PRISM_LAUNCHER_VERSION=10.0.5
```

**GOOD - Full commit SHA:**
```bash
PRISM_LAUNCHER_COMMIT=062a556abc123def456789...
```

**BAD - Branch reference:**
```bash
PRISM_LAUNCHER_BRANCH=develop  # Floating, changes without notice
```

**BAD - "latest" concept:**
```bash
PRISM_LAUNCHER_VERSION=latest  # Ambiguous, not reproducible
```

---

## Java Runtime Pin

### Required Versions

Minecraft requires specific Java versions based on game version:

| Java Version | Minecraft Versions | Package |
|--------------|-------------------|---------|
| **21** | 1.21+ | `openjdk-21-jre` |
| **17** | 1.18 - 1.20.4 | `openjdk-17-jre` |
| **8** | 1.16 and below | `openjdk-8-jre` |

### Pinning Strategy

Java runtimes are installed via Debian/Ubuntu package manager:

```dockerfile
ARG REQUIRED_PACKAGES=" \
    openjdk-21-jre \
    openjdk-17-jre \
    openjdk-8-jre \
    "
```

### Version Constraints

- **Base OS:** Inherits from `base-app` (Debian-based)
- **Package Pinning:** Use `apt-get install packagename=version` for explicit pins if needed
- **Security Updates:** Allow minor/patch updates within major version

### Configuration

```bash
# In pins.env
JAVA_VERSIONS="21 17 8"
```

---

## Update Cadence

### Review Schedule

| Trigger | Action | Reviewer |
|---------|--------|----------|
| **Monthly** | Review all pins for security updates | Maintainer |
| **Critical CVE** | Immediate review and patch | Maintainer |
| **Upstream Release** | Evaluate within 7 days | Maintainer |
| **Dependency EOL** | Plan migration | Maintainer |

### Pin Bump Process

1. **Assess Impact**
   - Review upstream changelog
   - Check for breaking changes
   - Verify compatibility with GoW base

2. **Test in Isolation**
   - Build image with new pin
   - Run smoke tests
   - Verify offline profile functionality

3. **Document Change**
   - Update `build/pins.env`
   - Update this policy document
   - Create changelog entry

4. **Deploy**
   - Merge to main branch
   - CI builds and publishes new image
   - Tag with appropriate version

### Freeze Periods

During these periods, pin bumps require additional approval:

- **Pre-release:** 1 week before any tagged release
- **Post-incident:** 48 hours after any production incident

---

## Verification Checklist

Before merging any pin bump:

### Base Image Bump

- [ ] Pull new base image locally
- [ ] Verify image signature/digest
- [ ] Review base image changelog
- [ ] Build derived image successfully
- [ ] Run smoke tests
- [ ] Verify GPU acceleration (NVIDIA + AMD)
- [ ] Check startup scripts execute correctly

### Launcher Source Bump

- [ ] Clone and diff source changes
- [ ] Verify only intended modifications (MSA gate removal)
- [ ] Check for new dependencies
- [ ] Build from source successfully
- [ ] Test offline profile creation
- [ ] Verify instance launch
- [ ] Test mod loader installation
- [ ] Confirm no regressions in existing functionality

### Java Runtime Bump

- [ ] Install new package versions
- [ ] Verify `java -version` output
- [ ] Test Minecraft launches with each version
- [ ] Confirm no conflicts between versions

### Final Sign-Off

- [ ] All checklist items passed
- [ ] No new linting errors
- [ ] Documentation updated
- [ ] Changelog entry added
- [ ] PR approved by maintainer

---

## Rollback Triggers

Immediate rollback is required if ANY condition is met:

### Critical Triggers (Immediate Rollback)

| Trigger | Action |
|---------|--------|
| **Image fails to start** | Revert pin, investigate in branch |
| **Authentication bypass appears** | Revert, security review |
| **Data loss/corruption** | Revert, user notification |
| **CVE in pinned version** | Revert to known-good, patch |

### Warning Triggers (Investigate First)

| Trigger | Action |
|---------|--------|
| **Performance regression > 20%** | Profile, assess, potentially revert |
| **New crash reports** | Triage severity, patch or revert |
| **Compatibility reports** | Investigate, document workaround |

### Rollback Procedure

1. **Identify Last Known Good**
   ```bash
   # Check previous pins in git history
   git log --oneline build/pins.env
   ```

2. **Revert Pin**
   ```bash
   # Revert to previous commit
   git revert HEAD -- build/pins.env
   ```

3. **Rebuild and Publish**
   ```bash
   # Force rebuild with reverted pins
   # CI handles versioning
   ```

4. **Post-Mortem**
   - Document trigger in issues
   - Root cause analysis
   - Update policy if needed

---

## Forbidden Sources

### Explicitly Banned

The following sources **MUST NEVER** be used in this project:

| Source | Reason | Severity |
|--------|--------|----------|
| **TLauncher** | Malware detections on ANY.RUN, closed source, data exfiltration | **CRITICAL** |
| **SKLauncher** | Malware detections, unauthorized data collection | **CRITICAL** |
| **ATLauncher (unofficial mirrors)** | Supply chain risk, unverifiable | **HIGH** |
| **Any "cracked" launcher from unverified source** | Malware risk, legal issues | **CRITICAL** |
| **Direct binary downloads without checksum** | Tampering risk | **HIGH** |
| **CurseForge modpacks (auto-download)** | ToS concerns, licensing | **MEDIUM** |

### TLauncher / SKLauncher Evidence

Both launchers have been flagged by security researchers:

- **ANY.RUN Analysis:** Multiple malware detections
- **Network Traffic:** Unauthorized data exfiltration observed
- **Code Audit:** Closed source, no transparency
- **Community Reports:** Account theft, adware injection

**These are NOT acceptable alternatives for offline play.**

### Acceptable Alternatives

For legitimate offline Minecraft usage:

1. **Official Prism Launcher** - Requires MSA once, then offline accounts available
2. **Prism Launcher (community forks)** - MSA gate removed, fully auditable
3. **MultiMC** - Supports offline accounts natively

### Source Verification Requirements

All sources MUST meet these criteria:

- [ ] Open source (GPL or compatible)
- [ ] Public repository with commit history
- [ ] Release signatures or verified commits
- [ ] Active maintenance (commits within 6 months)
- [ ] No malware reports from reputable sources
- [ ] Clear license terms

---

## Appendix A: pins.env Format

The `build/pins.env` file uses shell-compatible format:

```bash
# Source: https://github.com/games-on-whales/gow
# Pin Type: Tag + Digest (immutable)
BASE_APP_IMAGE=ghcr.io/games-on-whales/base-app:edge@sha256:66cb03a499a78bd81e75aa89eb7b33d5ee679355a8dae24d2989b9fd56e46b04

# Source: https://github.com/Diegiwg/PrismLauncher-Cracked
# Pin Type: Release Tag
PRISM_LAUNCHER_SOURCE=https://github.com/Diegiwg/PrismLauncher-Cracked
PRISM_LAUNCHER_VERSION=10.0.5

# Java Runtimes (space-separated)
# Installed via apt from Debian repositories
JAVA_VERSIONS="21 17 8"
```

### Sourcing in Dockerfile

```dockerfile
# Load pins
ARG BASE_APP_IMAGE
ARG PRISM_LAUNCHER_VERSION
ARG JAVA_VERSIONS

FROM ${BASE_APP_IMAGE}
# ... rest of Dockerfile
```

### Sourcing in Shell Scripts

```bash
#!/bin/bash
set -euo pipefail

# Source pins
source build/pins.env

echo "Building with Prism ${PRISM_LAUNCHER_VERSION}"
```

---

## Appendix B: Reference Links

- [GoW Official Prism Launcher Docs](https://games-on-whales.github.io/wolf/stable/apps/prismlauncher.html)
- [GoW GitHub Repository](https://github.com/games-on-whales/gow)
- [Prism Launcher (Official)](https://github.com/PrismLauncher/PrismLauncher)
- [Prism Launcher Cracked (Community Fork)](https://github.com/Diegiwg/PrismLauncher-Cracked)
- [AUR: prismlauncher-offline](https://aur.archlinux.org/packages/prismlauncher-offline)

---

## Changelog

| Date | Version | Changes |
|------|---------|---------|
| 2026-02-25 | 1.1.0 | T8: Base image digest pinning complete, added .dockerignore, hardened Dockerfile |
| 2026-02-25 | 1.0.0 | Initial policy document |
