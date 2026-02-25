# Release Checklist

## Pre-release

- [ ] Update pins in `build/pins.env` (if needed)
- [ ] Build image locally
- [ ] Run smoke tests: `./tests/run-all-smoke.sh`
- [ ] Run policy checks: `./tests/policy-check.sh --strict`
- [ ] Update `CHANGELOG.md`

## Release

- [ ] Commit release changes
- [ ] Create semantic tag `vX.Y.Z`
- [ ] Push tag to trigger workflow

## Post-release

- [ ] Confirm tags in GHCR
- [ ] Pull released image and verify basic startup
- [ ] Confirm docs/examples reference valid tags
