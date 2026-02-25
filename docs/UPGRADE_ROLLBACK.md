# Upgrade and Rollback

## Upgrade Flow

1. Update pin values in `build/pins.env`.
2. Build and run smoke tests.
3. Run policy checks.
4. Open and merge PR.
5. Tag release if needed.

## Rollback Flow

If a release is unhealthy:

1. Point Wolf image reference to a known-good version tag.
2. Restart Wolf.
3. Verify startup and basic launcher behavior.

Use immutable version tags for rollback targets.

## Quick Commands

```bash
./tests/run-all-smoke.sh
./tests/policy-check.sh --strict
```
