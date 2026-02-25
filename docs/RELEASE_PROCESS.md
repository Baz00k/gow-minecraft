# Release Process

## Tag Behavior

- Push to `main`: publishes `edge` and `sha-*` tags.
- Push semantic tag `vX.Y.Z`: publishes version tags and updates `latest`.
- Pull requests: build and test only, no publish.

## Create a Release

1. Ensure `main` is healthy (policy check + smoke tests pass).
2. Update changelog.
3. Create and push a semantic tag:

   ```bash
   git tag -a v1.2.3 -m "Release v1.2.3"
   git push origin v1.2.3
   ```

4. Verify published tags in GHCR.

## Verify Published Image

```bash
docker pull ghcr.io/OWNER/gow-prism-offline:1.2.3
docker inspect ghcr.io/OWNER/gow-prism-offline:1.2.3
```
