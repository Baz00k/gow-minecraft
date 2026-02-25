#!/bin/bash
set -euo pipefail
# =============================================================================
# Smoke Test Orchestrator
# =============================================================================
# Runs all smoke tests in sequence and reports results.
#
# Usage:
#   ./run-all-smoke.sh
#
# Environment Variables:
#   IMAGE_NAME    - Docker image name (default: gow-prism-offline:test)
#   SKIP_BUILD    - Set to "true" to skip the build test (default: false)
#   BUILD_TIMEOUT - Build timeout in seconds (default: 600)
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE_NAME="${IMAGE_NAME:-gow-prism-offline:test}"
SKIP_BUILD="${SKIP_BUILD:-false}"
BUILD_TIMEOUT="${BUILD_TIMEOUT:-600}"
EVIDENCE_DIR="$(dirname "$0")/../.sisyphus/evidence"
EVIDENCE_FILE="${EVIDENCE_DIR}/task-6-all.txt"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Test tracking
TESTS_TOTAL=0
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

log_header() {
    echo ""
    echo -e "${BOLD}${BLUE}========================================${NC}"
    echo -e "${BOLD}${BLUE}$*${NC}"
    echo -e "${BOLD}${BLUE}========================================${NC}"
    echo ""
}

log_info() {
    echo -e "${GREEN}[INFO]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_test_start() {
    echo -e "${BOLD}[TEST]${NC} Running: $*"
}

log_test_pass() {
    echo -e "${GREEN}[PASS]${NC} $*"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

log_test_fail() {
    echo -e "${RED}[FAIL]${NC} $*"
    TESTS_FAILED=$((TESTS_FAILED + 1))
}

log_test_skip() {
    echo -e "${YELLOW}[SKIP]${NC} $*"
    TESTS_SKIPPED=$((TESTS_SKIPPED + 1))
}

# Ensure evidence directory exists
mkdir -p "${EVIDENCE_DIR}"

# Initialize evidence file
{
    echo "=== Smoke Test Suite: All Tests ==="
    echo "Timestamp: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    echo "Image: ${IMAGE_NAME}"
    echo "Skip Build: ${SKIP_BUILD}"
    echo ""
} > "${EVIDENCE_FILE}"

START_TIME=$(date +%s)

log_header "GoW Prism Offline Image - Smoke Test Suite"
echo "Image: ${IMAGE_NAME}"
echo "Timestamp: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
echo ""

# =============================================================================
# Test 1: Build
# =============================================================================
TESTS_TOTAL=$((TESTS_TOTAL + 1))

if [[ "${SKIP_BUILD}" == "true" ]]; then
    log_test_skip "Build test (SKIP_BUILD=true)"
    echo "1. BUILD: SKIPPED" >> "${EVIDENCE_FILE}"
else
    log_test_start "Docker Build"
    if "${SCRIPT_DIR}/smoke-build.sh"; then
        log_test_pass "Docker Build"
        echo "1. BUILD: PASSED" >> "${EVIDENCE_FILE}"
    else
        log_test_fail "Docker Build"
        echo "1. BUILD: FAILED" >> "${EVIDENCE_FILE}"
    fi
fi

# =============================================================================
# Test 2: Startup
# =============================================================================
TESTS_TOTAL=$((TESTS_TOTAL + 1))
log_test_start "Container Startup"

if "${SCRIPT_DIR}/smoke-startup.sh"; then
    log_test_pass "Container Startup"
    echo "2. STARTUP: PASSED" >> "${EVIDENCE_FILE}"
else
    log_test_fail "Container Startup"
    echo "2. STARTUP: FAILED" >> "${EVIDENCE_FILE}"
fi

# =============================================================================
# Test 3: Java Runtimes
# =============================================================================
TESTS_TOTAL=$((TESTS_TOTAL + 1))
log_test_start "Java Runtime Availability"

if "${SCRIPT_DIR}/smoke-java.sh"; then
    log_test_pass "Java Runtime Availability"
    echo "3. JAVA: PASSED" >> "${EVIDENCE_FILE}"
else
    log_test_fail "Java Runtime Availability"
    echo "3. JAVA: FAILED" >> "${EVIDENCE_FILE}"
fi

# =============================================================================
# Test 4: Persistence
# =============================================================================
TESTS_TOTAL=$((TESTS_TOTAL + 1))
log_test_start "Data Persistence"

if "${SCRIPT_DIR}/smoke-persistence.sh"; then
    log_test_pass "Data Persistence"
    echo "4. PERSISTENCE: PASSED" >> "${EVIDENCE_FILE}"
else
    log_test_fail "Data Persistence"
    echo "4. PERSISTENCE: FAILED" >> "${EVIDENCE_FILE}"
fi

# =============================================================================
# Summary
# =============================================================================
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

{
    echo ""
    echo "=== Summary ==="
    echo "Total: ${TESTS_TOTAL}"
    echo "Passed: ${TESTS_PASSED}"
    echo "Failed: ${TESTS_FAILED}"
    echo "Skipped: ${TESTS_SKIPPED}"
    echo "Duration: ${DURATION}s"
    echo ""
} >> "${EVIDENCE_FILE}"

log_header "Test Summary"

echo "Total Tests:   ${TESTS_TOTAL}"
echo "Passed:        ${TESTS_PASSED}"
echo "Failed:        ${TESTS_FAILED}"
echo "Skipped:       ${TESTS_SKIPPED}"
echo "Duration:      ${DURATION}s"
echo ""

# Evidence file listing
echo "Evidence files written to:"
ls -la "${EVIDENCE_DIR}"/task-6-*.txt 2>/dev/null || echo "  (none)"
echo ""

# Final result
if [[ ${TESTS_FAILED} -gt 0 ]]; then
    echo -e "${RED}${BOLD}=== TESTS FAILED ===${NC}"
    echo "RESULT: FAILED" >> "${EVIDENCE_FILE}"
    exit 1
else
    echo -e "${GREEN}${BOLD}=== ALL TESTS PASSED ===${NC}"
    echo "RESULT: PASSED" >> "${EVIDENCE_FILE}"
    exit 0
fi
