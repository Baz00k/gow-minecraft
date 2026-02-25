# Test Results

Test scripts write runtime output to:

```text
test-results/evidence/
```

## Local Use

Run all smoke tests:

```bash
./tests/run-all-smoke.sh
```

Check result files:

```bash
ls -la test-results/evidence/
grep -R "RESULT:" test-results/evidence/
```

## CI Use

On failure, workflows upload `test-results/evidence/` as artifacts for debugging.
