# Release Process

This document describes the tagging and release strategy for the GoW Prism Launcher Offline Docker image.

## Tag Types

| Tag | Description | When Published |
|-----|-------------|----------------|
| `latest` | Points to the highest semantic version | On version tag push (e.g., `v1.0.0`) |
| `edge` | Latest main branch build | On push to `main` branch |
| `v1.0.0` | Full semantic version | On tag push matching `v*` pattern |
| `v1.0` | Major.minor version | On tag push matching `v*` pattern |
| `v1` | Major version only | On tag push matching `v*` pattern |
| `sha-abc123` | Commit SHA prefix | On any push to main or tag |

## Tagging Strategy

The workflow uses `docker/metadata-action` to automatically generate tags based on the event type:

### Semantic Version Tags

When a version tag is pushed (e.g., `v1.2.3`), the following tags are created:

```
ghcr.io/OWNER/gow-prism-offline:1.2.3    # Full version
ghcr.io/OWNER/gow-prism-offline:1.2      # Major.minor
ghcr.io/OWNER/gow-prism-offline:1        # Major only
ghcr.io/OWNER/gow-prism-offline:latest   # Highest semver
ghcr.io/OWNER/gow-prism-offline:sha-abc1234  # Commit SHA
```

### Edge Tag

Pushes to the `main` branch publish the `edge` tag:

```
ghcr.io/OWNER/gow-prism-offline:edge
ghcr.io/OWNER/gow-prism-offline:sha-abc1234
```

### Pull Requests

PR builds do **not** publish to the registry. They only validate the build succeeds.

## Creating a Release

### Step 1: Ensure Quality

Before creating a release:
1. All tests pass on `main` branch
2. The `edge` image has been validated
3. Changelog is updated (if applicable)

### Step 2: Create and Push Tag

```bash
# Create annotated tag
git tag -a v1.2.3 -m "Release v1.2.3: Brief description"

# Push tag to trigger CI
git push origin v1.2.3
```

### Step 3: Verify CI Build

1. Navigate to **Actions** tab in GitHub
2. Find the workflow run triggered by the tag push
3. Verify build completes successfully
4. Check published tags at: `https://github.com/OWNER/gow-prism-offline/pkgs/container/gow-prism-offline`

### Step 4: Create GitHub Release (Optional)

```bash
# Using gh CLI
gh release create v1.2.3 --title "v1.2.3" --notes "Release notes here"
```

## Branch Conventions

| Branch | Purpose | Publishes |
|--------|---------|-----------|
| `main` | Stable development | `edge`, `sha-*` |
| `develop` | Feature integration | No (PR validation only) |
| `release/*` | Release preparation | No (PR validation only) |
| Feature branches | Individual features | No (PR validation only) |

## Immutable Traceability

Every published image can be traced back to its source commit:

1. **SHA tag** (`sha-abc123`): Directly maps to the Git commit SHA
2. **Version tags**: Include the SHA in image labels
3. **Provenance**: Images include SLSA provenance for supply chain security
4. **SBOM**: Software Bill of Materials attached to each image

To inspect image metadata:

```bash
docker inspect ghcr.io/OWNER/gow-prism-offline:1.2.3 \
  --format '{{ json .Config.Labels }}' | jq
```

## GHCR Package URL

Images are published to GitHub Container Registry:

```
ghcr.io/OWNER/gow-prism-offline
```

Replace `OWNER` with the GitHub repository owner/organization name.

### Pulling Images

```bash
# Latest stable release
docker pull ghcr.io/OWNER/gow-prism-offline:latest

# Specific version
docker pull ghcr.io/OWNER/gow-prism-offline:1.2.3

# Development build
docker pull ghcr.io/OWNER/gow-prism-offline:edge
```

## Verification Commands

### Check Available Tags

```bash
# List tags via GitHub API
gh api /users/OWNER/packages/container/gow-prism-offline/versions \
  --jq '.[] | .metadata.container.tags'
```

### Verify Image Digest

```bash
# Get digest for a tag
docker buildx imagetools inspect \
  ghcr.io/OWNER/gow-prism-offline:1.2.3 \
  --format '{{ .Digest }}'
```

### Compare Tags

```bash
# Verify two tags point to same image
docker buildx imagetools inspect \
  ghcr.io/OWNER/gow-prism-offline:latest \
  --format '{{ .Digest }}'

docker buildx imagetools inspect \
  ghcr.io/OWNER/gow-prism-offline:1.2.3 \
  --format '{{ .Digest }}'
```

## Rollback Procedure

To roll back to a previous version:

1. Identify the target version tag
2. Create a new tag pointing to the same commit:
   ```bash
   git tag -a v1.2.4 <commit-sha> -m "Rollback to v1.2.3 state"
   git push origin v1.2.4
   ```
3. Or use `latest` to point to an existing version by re-tagging

**Note:** Never delete and re-create tags. Always create new version tags for rollbacks to maintain immutability.

## Troubleshooting

### Tag Not Appearing in GHCR

1. Verify workflow completed successfully
2. Check package visibility settings: Settings → Packages → gow-prism-offline
3. Ensure `packages: write` permission is set in workflow

### Version Tag Not Generating Semver Tags

- Tag must start with `v` (e.g., `v1.0.0`, not `1.0.0`)
- Tag must follow semantic versioning format

### Latest Tag Not Updating

- `latest=auto` means latest only updates for semver tags
- Pushes to main only update `edge`, not `latest`
