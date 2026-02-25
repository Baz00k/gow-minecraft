# Release Checklist

**Document Status:** Active
**Last Updated:** 2026-02-25
**Applies To:** GoW Prism Launcher Offline-Enabled Docker Image

---

## Overview

This checklist defines the step-by-step process for releasing a new version of the GoW Prism Launcher offline-enabled Docker image. Follow each section in order.

### Versioning Convention

This project follows [Semantic Versioning 2.0.0](https://semver.org/spec/v2.0.0.html):

- **MAJOR (X.0.0):** Breaking changes to Wolf config format, removed features
- **MINOR (0.Y.0):** New features, dependency updates, new architectures
- **PATCH (0.0.Z):** Bug fixes, documentation updates, minor improvements

---

## Pre-Release Checklist

### 1. Update Dependencies (if needed)

```bash
# Check current pins
cat build/pins.env

# If updating base image, fetch new digest
docker pull ghcr.io/games-on-whales/base-app:edge
docker inspect --format='{{index .RepoDigests 0}}' ghcr.io/games-on-whales/base-app:edge

# If updating Prism Launcher, download new AppImages and calculate checksums
curl -LO https://github.com/Diegiwg/PrismLauncher-Cracked/releases/download/NEW_VERSION/PrismLauncher-Linux-x86_64.AppImage
sha256sum PrismLauncher-Linux-x86_64.AppImage
```

Update `build/pins.env` with new values. See [PINNING_POLICY.md](./PINNING_POLICY.md) for detailed process.

### 2. Test Build Locally

```bash
# Build the image
docker build \
  --build-arg BASE_APP_IMAGE=$(grep BASE_APP_IMAGE build/pins.env | cut -d= -f2) \
  --build-arg PRISM_LAUNCHER_VERSION=$(grep PRISM_LAUNCHER_VERSION build/pins.env | cut -d= -f2) \
  -t gow-prism-offline:test \
  -f build/Dockerfile \
  .

# Run smoke tests
./tests/smoke-tests/run-all-smoke.sh

# Run policy checks
./tests/policy-check.sh --strict
```

All tests must pass before proceeding.

### 3. Update CHANGELOG.md

Add release notes following [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) format:

```markdown
## [X.Y.Z] - YYYY-MM-DD

### Added

- New feature description

### Changed

- Updated dependency from A to B

### Fixed

- Bug fix description

### Security

- Security improvement description
```

Move items from `[Unreleased]` section to the new version section.

### 4. Verify Documentation

- [ ] CHANGELOG.md has complete release notes
- [ ] README.md reflects current state (if changed)
- [ ] docs/PINNING_POLICY.md reflects current pins (if changed)
- [ ] No references to old version numbers remain

---

## Create Release Tag

### 1. Commit and Push Changes

```bash
# Stage all changes
git add .

# Commit with clear message
git commit -m "chore: release v1.2.3"

# Push to main
git push origin main
```

### 2. Create Git Tag

```bash
# Create annotated tag (recommended)
git tag -a v1.2.3 -m "Release v1.2.3: Brief description of main changes"

# Push tag to trigger CI
git push origin v1.2.3
```

**Tag naming rules:**

- Must start with `v` (lowercase)
- Must follow semver: `vX.Y.Z` where X, Y, Z are non-negative integers
- Examples: `v1.0.0`, `v1.2.3`, `v2.0.0`

---

## Verify CI Workflow

### 1. Monitor GitHub Actions

Navigate to: `https://github.com/YOUR_USERNAME/gow-minecraft/actions`

Or use CLI:

```bash
# List recent workflow runs
gh run list --limit 5

# Watch specific run
gh run watch
```

### 2. Verify Build Success

The `Build and Publish Docker Image` workflow should:

- Complete without errors
- Show green checkmark for the tag push
- Display image digest in the logs

### 3. Check Workflow Logs

Expand the "Build and push Docker image" step and verify:

- Build completed successfully
- Push to GHCR succeeded
- Expected tags were generated

---

## Verify GHCR Publication

### 1. Check Package Page

Navigate to: `https://github.com/YOUR_USERNAME?tab=packages`

Or directly: `https://github.com/YOUR_USERNAME/gow-prism-offline/pkgs/container/gow-prism-offline`

### 2. Verify Tags Exist

For version `v1.2.3`, the following tags should be present:

| Tag           | Description                     |
| ------------- | ------------------------------- |
| `1.2.3`       | Full semver version             |
| `1.2`         | Major.minor version             |
| `1`           | Major version                   |
| `latest`      | Points to highest semver (auto) |
| `sha-abc1234` | Commit SHA reference            |

### 3. Pull and Verify Image

```bash
# Pull the new version
docker pull ghcr.io/YOUR_USERNAME/gow-prism-offline:1.2.3

# Verify image metadata
docker inspect ghcr.io/YOUR_USERNAME/gow-prism-offline:1.2.3 | jq '.[0].Config.Labels'

# Check version label matches
docker inspect --format='{{index .Config.Labels "org.opencontainers.image.version"}}' ghcr.io/YOUR_USERNAME/gow-prism-offline:1.2.3

# Verify digest
docker inspect --format='{{.Id}}' ghcr.io/YOUR_USERNAME/gow-prism-offline:1.2.3
```

### 4. Quick Smoke Test

```bash
# Run a quick test with the published image
docker run --rm ghcr.io/YOUR_USERNAME/gow-prism-offline:1.2.3 \
  ls -la /opt/prismlauncher/

# Verify Java runtimes
docker run --rm ghcr.io/YOUR_USERNAME/gow-prism-offline:1.2.3 \
  java -version
```

---

## Post-Release Checklist

### 1. Update Documentation References

- [ ] Update any version references in documentation
- [ ] Verify all links in README.md work
- [ ] Check that example commands use appropriate version

### 2. Update Wolf Config Examples

If Wolf app config changed, update `config/` templates:

```bash
# Verify templates are up to date
cat config/wolf-app-nvidia.toml
cat config/wolf-app-amd-intel.toml
```

### 3. Create GitHub Release (Optional)

```bash
# Create release with auto-generated notes
gh release create v1.2.3 \
  --title "v1.2.3" \
  --notes-file <(echo "See [CHANGELOG.md](./CHANGELOG.md) for details.")
```

Or manually at: `https://github.com/YOUR_USERNAME/gow-minecraft/releases/new`

### 4. Announce (if applicable)

- Update any community channels
- Notify downstream users of breaking changes
- Document any required migration steps

---

## Rollback Procedure

If issues are discovered post-release:

### Option 1: Pin Previous Version in Wolf

Update Wolf app config to use the previous working tag:

```toml
# In Wolf config
[runner]
image = "ghcr.io/YOUR_USERNAME/gow-prism-offline:1.2.2"  # Pin to previous
```

### Option 2: Rebuild with Old Pins

```bash
# Find previous good commit
git log --oneline build/pins.env

# Revert pins to previous version
git revert <commit-sha> -- build/pins.env

# Tag as patch release
git tag -a v1.2.4 -m "Rollback to pins from v1.2.2"
git push origin v1.2.4
```

See [UPGRADE_ROLLBACK.md](./UPGRADE_ROLLBACK.md) for detailed rollback procedures.

---

## Quick Reference Commands

```bash
# Pre-release
./tests/smoke-tests/run-all-smoke.sh    # Run smoke tests
./tests/policy-check.sh --strict        # Run policy checks

# Tag and push
git tag -a v1.2.3 -m "Release v1.2.3"   # Create tag
git push origin v1.2.3                   # Push tag (triggers CI)

# Verify
gh run watch                             # Watch CI workflow
docker pull ghcr.io/OWNER/gow-prism-offline:1.2.3  # Pull published image

# Rollback
git log --oneline build/pins.env         # Find previous pins
```

---

## Checklist Summary

Print this section for quick reference during releases:

```
RELEASE CHECKLIST v1.2.3

PRE-RELEASE
[ ] Dependencies updated in build/pins.env
[ ] Local build successful
[ ] Smoke tests passed
[ ] Policy checks passed
[ ] CHANGELOG.md updated with release notes
[ ] Documentation reviewed

TAG AND CI
[ ] Changes committed and pushed to main
[ ] Git tag v1.2.3 created and pushed
[ ] GitHub Actions workflow completed successfully

VERIFICATION
[ ] Image visible on GHCR package page
[ ] All expected tags present (1.2.3, 1.2, 1, latest, sha-*)
[ ] Image pulls successfully
[ ] Version label correct
[ ] Quick smoke test passed

POST-RELEASE
[ ] Documentation references updated
[ ] GitHub release created (optional)
[ ] Announcements made (if applicable)
```

---

## Related Documents

- [PINNING_POLICY.md](./PINNING_POLICY.md) — Dependency pinning procedures
- [UPGRADE_ROLLBACK.md](./UPGRADE_ROLLBACK.md) — Detailed upgrade and rollback procedures
- [OPERATOR_GUIDE.md](./OPERATOR_GUIDE.md) — Wolf integration guide
- [CHANGELOG.md](../CHANGELOG.md) — Version history
