# Pinning Policy

This repository pins upstream dependencies to keep builds reproducible and auditable.

## What Must Be Pinned

- Base image (`BASE_APP_IMAGE`) with digest (`@sha256:...`)
- Prism Launcher release version
- Prism Launcher AppImage URLs and SHA256 checksums

Values are stored in `build/pins.env`.

## Update Process

1. Update pins in `build/pins.env`.
2. Rebuild image.
3. Run smoke tests.
4. Run policy check.
5. Update release notes if this affects a release.

## Verification Commands

```bash
./tests/policy-check.sh --strict
./tests/run-all-smoke.sh
```

## Prohibited Patterns

- Floating-only refs for production pins (`:latest`, `:edge` without digest)
- Binary downloads without checksum verification
- References to forbidden launcher sources (enforced by policy checks)
