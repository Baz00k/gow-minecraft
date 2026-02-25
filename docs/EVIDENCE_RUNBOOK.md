# Evidence Capture Runbook

This document defines the standard for evidence naming, storage, and minimum capture requirements across all build, test, and policy tasks.

## Quick Reference

| Item | Value |
|------|-------|
| Storage Location | `.sisyphus/evidence/` |
| Naming Format | `task-{N}-{scenario}.txt` |
| Timestamp Format | ISO 8601 UTC (`%Y-%m-%dT%H:%M:%SZ`) |
| Result Marker | `RESULT: PASSED` or `RESULT: FAILED` |

## Naming Convention

### Format

```
task-{task-number}-{scenario}.txt
```

- `task-number`: Zero-padded task number from the project plan (e.g., `06`, `11`, `12`)
- `scenario`: Short descriptive name for the evidence type (e.g., `build`, `startup`, `java`, `persistence`, `all`)

### Examples

```
.sisyphus/evidence/
├── task-06-build.txt        # Build task evidence
├── task-06-startup.txt      # Container startup test evidence
├── task-06-java.txt         # Java runtime test evidence
├── task-06-persistence.txt  # Data persistence test evidence
├── task-06-all.txt          # Aggregated smoke test suite evidence
├── task-11-persistence.txt  # Persistence validation evidence
└── task-12-operator.txt     # Operator documentation validation evidence
```

## Storage Location

All evidence files must be stored in:

```
.sisyphus/evidence/
```

### Directory Setup

Scripts must ensure the directory exists before writing:

```bash
EVIDENCE_DIR="$(dirname "$0")/../.sisyphus/evidence"
mkdir -p "${EVIDENCE_DIR}"
```

### Git Ignore

The `.sisyphus/` directory should be in `.gitignore` as evidence is generated at runtime, not committed to source control.

## Evidence File Structure

### Required Header

Every evidence file must start with:

```
=== {Test Name} ===
Timestamp: {ISO8601-UTC}
Image: {image-name}
{additional-context}
```

### Required Footer

Every evidence file must end with:

```
RESULT: PASSED
```

or

```
RESULT: FAILED {reason}
```

### Example Structure

```
=== Smoke Test: Docker Build ===
Timestamp: 2026-02-25T03:30:00Z
Image: gow-prism-offline:test
Build Context: /path/to/build

=== Build Log ===
{full build output}

=== Build Result ===
Exit Code: 0
Duration: 120s
Image Size: 1.25 GB (1347420160 bytes)

RESULT: PASSED
```

## Minimum Requirements by Task Type

### Build Tasks

Evidence files for build tasks must capture:

| Field | Required | Description |
|-------|----------|-------------|
| Timestamp | Yes | Build start time in ISO 8601 UTC |
| Image Name | Yes | Target image name and tag |
| Build Context | Yes | Path to build context directory |
| Build Log | Yes | Full docker build output |
| Exit Code | Yes | Docker build exit code (0 = success) |
| Duration | Yes | Build time in seconds |
| Image Size | Yes | Final image size in bytes and human-readable format |
| Result | Yes | PASSED or FAILED with reason |

**Example filename:** `task-06-build.txt`

### Test Tasks

Evidence files for test tasks must capture:

| Field | Required | Description |
|-------|----------|-------------|
| Timestamp | Yes | Test execution time in ISO 8601 UTC |
| Image Name | Yes | Docker image being tested |
| Container Name | Yes | Test container identifier |
| Test Steps | Yes | Individual test step results |
| Output | Yes | Relevant command output |
| Summary | Yes | Total/passed/failed/skipped counts |
| Duration | Yes | Test duration in seconds |
| Result | Yes | PASSED or FAILED with counts |

**Example filenames:**
- `task-06-startup.txt` - Container startup validation
- `task-06-java.txt` - Java runtime availability
- `task-06-persistence.txt` - Data persistence verification

### Policy Tasks

Evidence files for policy/validation tasks must capture:

| Field | Required | Description |
|-------|----------|-------------|
| Timestamp | Yes | Validation time in ISO 8601 UTC |
| Scope | Yes | What was validated |
| Files Checked | Yes | List of files examined |
| Violations | Yes | Any policy violations found |
| Checks Performed | Yes | List of validation checks |
| Result | Yes | PASSED or FAILED with details |

**Example filename:** `task-12-operator.txt`

### Aggregated Evidence

When running multiple tests in a suite:

| Field | Required | Description |
|-------|----------|-------------|
| Suite Name | Yes | Name of the test suite |
| Timestamp | Yes | Suite start time |
| Individual Results | Yes | Pass/fail for each test |
| Summary | Yes | Aggregated totals |
| Result | Yes | Overall suite result |

**Example filename:** `task-06-all.txt`

## Evidence Types

### Build Logs

Full output from `docker build` command, including:

- Build steps executed
- Package installation output
- Layer creation details
- Any warnings or errors

### Test Results

Structured test output including:

- Test case names
- Pass/fail status per test
- Error messages for failures
- Performance metrics where applicable

### Policy Check Results

Output from validation scripts including:

- Files or configurations checked
- Compliance status
- Any violations or warnings

## CI Integration

### GitHub Actions

Evidence should be captured as workflow artifacts:

```yaml
- name: Run Smoke Tests
  run: ./tests/run-all-smoke.sh

- name: Upload Evidence
  if: always()  # Upload even on failure
  uses: actions/upload-artifact@v4
  with:
    name: smoke-test-evidence
    path: .sisyphus/evidence/
    retention-days: 30
```

### Evidence Retention

- CI artifacts: 30 days minimum
- Release builds: 90 days or permanent archive
- Failed builds: 14 days minimum for debugging

### CI Evidence Path Pattern

```
{workflow-run-id}/
├── task-06-build.txt
├── task-06-startup.txt
├── task-06-java.txt
├── task-06-persistence.txt
└── task-06-all.txt
```

## Local Verification

### Check Evidence Completeness

```bash
# List all evidence files
ls -la .sisyphus/evidence/task-*.txt

# Check for any failed results
grep -l "RESULT: FAILED" .sisyphus/evidence/*.txt && echo "FAILURES FOUND" || echo "ALL PASSED"

# Verify all required evidence exists for task 6
for scenario in build startup java persistence all; do
  file=".sisyphus/evidence/task-6-${scenario}.txt"
  if [[ -f "$file" ]]; then
    echo "✓ $file exists"
  else
    echo "✗ $file MISSING"
  fi
done
```

### Verify Evidence Format

```bash
# Check timestamp format
grep "Timestamp:" .sisyphus/evidence/*.txt

# Check result lines
grep "RESULT:" .sisyphus/evidence/*.txt

# Validate ISO 8601 timestamp format
for f in .sisyphus/evidence/*.txt; do
  ts=$(grep "^Timestamp:" "$f" | cut -d' ' -f2)
  if date -j -f "%Y-%m-%dT%H:%M:%SZ" "$ts" >/dev/null 2>&1; then
    echo "✓ $f: valid timestamp"
  else
    echo "✗ $f: invalid timestamp format"
  fi
done
```

### Extract Summary

```bash
# Quick summary of all evidence
for f in .sisyphus/evidence/task-*.txt; do
  echo "=== $(basename "$f") ==="
  head -4 "$f"
  tail -1 "$f"
  echo ""
done
```

## Evidence Capture Script Template

```bash
#!/bin/bash -euo pipefail
# Evidence capture setup
EVIDENCE_DIR="$(dirname "$0")/../.sisyphus/evidence"
EVIDENCE_FILE="${EVIDENCE_DIR}/task-{N}-{scenario}.txt"
IMAGE_NAME="${IMAGE_NAME:-gow-prism-offline:test}"

# Ensure evidence directory exists
mkdir -p "${EVIDENCE_DIR}"

# Initialize evidence file with header
{
    echo "=== {Test Name} ==="
    echo "Timestamp: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    echo "Image: ${IMAGE_NAME}"
    echo ""
} > "${EVIDENCE_FILE}"

# ... run tests, appending output to evidence ...

# Append result
if [[ success ]]; then
    echo "RESULT: PASSED" >> "${EVIDENCE_FILE}"
    exit 0
else
    echo "RESULT: FAILED ({reason})" >> "${EVIDENCE_FILE}"
    exit 1
fi
```

## Appendix: Current Evidence Files

| Task | Scenario | Script | Description |
|------|----------|--------|-------------|
| T6 | build | `tests/smoke-build.sh` | Docker build verification |
| T6 | startup | `tests/smoke-startup.sh` | Container startup and script validation |
| T6 | java | `tests/smoke-java.sh` | Java 21/17/8 runtime availability |
| T6 | persistence | `tests/smoke-persistence.sh` | Volume persistence across container recreation |
| T6 | all | `tests/run-all-smoke.sh` | Aggregated smoke test suite results |
