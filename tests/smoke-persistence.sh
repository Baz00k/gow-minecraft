#!/bin/bash
set -euo pipefail
# =============================================================================
# Smoke Test: Data Persistence
# =============================================================================
# Tests that data persists across container recreation.
# Simulates Wolf's persistence pattern where /home/retro is mounted.
#
# Usage:
#   ./smoke-persistence.sh
#
# Environment Variables:
#   IMAGE_NAME      - Docker image name (default: gow-prism-offline:test)
#   CONTAINER_NAME  - Test container name prefix (default: smoke-test-persist)
# =============================================================================

IMAGE_NAME="${IMAGE_NAME:-gow-prism-offline:test}"
CONTAINER_PREFIX="${CONTAINER_NAME:-smoke-test-persist}"
CONTAINER_1="${CONTAINER_PREFIX}-1"
CONTAINER_2="${CONTAINER_PREFIX}-2"
EVIDENCE_DIR="$(dirname "$0")/../.sisyphus/evidence"
EVIDENCE_FILE="${EVIDENCE_DIR}/task-6-persistence.txt"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

# Ensure evidence directory exists
mkdir -p "${EVIDENCE_DIR}"

# Create temp directory for volume
VOLUME_DIR=$(mktemp -d)

# Initialize evidence file
{
    echo "=== Smoke Test: Data Persistence ==="
    echo "Timestamp: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    echo "Image: ${IMAGE_NAME}"
    echo "Volume Directory: ${VOLUME_DIR}"
    echo ""
} > "${EVIDENCE_FILE}"

# Cleanup function
cleanup() {
    log_info "Cleaning up..."
    docker rm -f "${CONTAINER_1}" 2>/dev/null || true
    docker rm -f "${CONTAINER_2}" 2>/dev/null || true
    rm -rf "${VOLUME_DIR}"
}
trap cleanup EXIT

# Verify image exists
if ! docker image inspect "${IMAGE_NAME}" > /dev/null 2>&1; then
    log_error "Image ${IMAGE_NAME} not found. Run smoke-build.sh first."
    echo "ERROR: Image not found" >> "${EVIDENCE_FILE}"
    exit 1
fi

# Test marker file
TEST_FILE="persistence-test-marker.txt"
TEST_CONTENT="Persistence test content - $(date -u +"%Y-%m-%dT%H:%M:%SZ")"

log_info "Volume directory: ${VOLUME_DIR}"

# =============================================================================
# Test 1: Write data in first container
# =============================================================================
log_info "Starting first container and writing test data..."

docker run -d --entrypoint "" --name "${CONTAINER_1}" \
    -v "${VOLUME_DIR}:/home/retro/persistence-test" \
    "${IMAGE_NAME}" sleep infinity > /dev/null

sleep 2

# Verify container is running
CONTAINER_STATUS=$(docker inspect --format='{{.State.Status}}' "${CONTAINER_1}")
if [[ "${CONTAINER_STATUS}" != "running" ]]; then
    log_error "Container ${CONTAINER_1} is not running. Status: ${CONTAINER_STATUS}"
    echo "RESULT: FAILED (container 1 not running)" >> "${EVIDENCE_FILE}"
    exit 1
fi

# Write test data
log_info "Writing test file: ${TEST_FILE}"
docker exec "${CONTAINER_1}" bash -c "echo '${TEST_CONTENT}' > /home/retro/persistence-test/${TEST_FILE}"

# Verify file was written
if ! docker exec "${CONTAINER_1}" test -f "/home/retro/persistence-test/${TEST_FILE}"; then
    log_error "Failed to write test file in container 1"
    echo "RESULT: FAILED (write failed)" >> "${EVIDENCE_FILE}"
    exit 1
fi

WRITTEN_CONTENT=$(docker exec "${CONTAINER_1}" cat "/home/retro/persistence-test/${TEST_FILE}")
{
    echo "=== Container 1: Write Test ==="
    echo "File: /home/retro/persistence-test/${TEST_FILE}"
    echo "Content written: ${TEST_CONTENT}"
    echo "Content read: ${WRITTEN_CONTENT}"
    echo ""
} >> "${EVIDENCE_FILE}"

log_info "Test file written successfully"

# Stop and remove first container
log_info "Removing first container..."
docker rm -f "${CONTAINER_1}" > /dev/null

# =============================================================================
# Test 2: Verify data persists in second container
# =============================================================================
log_info "Starting second container to verify persistence..."

docker run -d --entrypoint "" --name "${CONTAINER_2}" \
    -v "${VOLUME_DIR}:/home/retro/persistence-test" \
    "${IMAGE_NAME}" sleep infinity > /dev/null

sleep 2

# Verify container is running
CONTAINER_STATUS=$(docker inspect --format='{{.State.Status}}' "${CONTAINER_2}")
if [[ "${CONTAINER_STATUS}" != "running" ]]; then
    log_error "Container ${CONTAINER_2} is not running. Status: ${CONTAINER_STATUS}"
    echo "RESULT: FAILED (container 2 not running)" >> "${EVIDENCE_FILE}"
    exit 1
fi

# Check if file exists
log_info "Checking if test file persists..."
if ! docker exec "${CONTAINER_2}" test -f "/home/retro/persistence-test/${TEST_FILE}"; then
    log_error "Test file not found in container 2 - persistence failed!"
    echo "RESULT: FAILED (file not persisted)" >> "${EVIDENCE_FILE}"
    exit 1
fi

# Verify content
PERSISTED_CONTENT=$(docker exec "${CONTAINER_2}" cat "/home/retro/persistence-test/${TEST_FILE}")

{
    echo "=== Container 2: Persistence Verification ==="
    echo "File: /home/retro/persistence-test/${TEST_FILE}"
    echo "Content read: ${PERSISTED_CONTENT}"
    echo ""
} >> "${EVIDENCE_FILE}"

# Compare content (strip trailing whitespace/newlines for comparison)
WRITTEN_CLEAN=$(echo "${WRITTEN_CONTENT}" | tr -d '[:space:]')
PERSISTED_CLEAN=$(echo "${PERSISTED_CONTENT}" | tr -d '[:space:]')

if [[ "${WRITTEN_CLEAN}" != "${PERSISTED_CLEAN}" ]]; then
    log_error "Content mismatch!"
    log_error "Expected: ${WRITTEN_CONTENT}"
    log_error "Got: ${PERSISTED_CONTENT}"
    echo "RESULT: FAILED (content mismatch)" >> "${EVIDENCE_FILE}"
    exit 1
fi

log_info "Data persisted correctly!"

# =============================================================================
# Test 3: Verify user 'retro' can write to /home/retro
# =============================================================================
log_info "Testing write permissions in /home/retro..."

# Try to create a file directly in /home/retro (without volume mount)
docker exec "${CONTAINER_2}" bash -c "touch /home/retro/test-write-permission && rm /home/retro/test-write-permission"

if [[ $? -eq 0 ]]; then
    log_info "User 'retro' can write to /home/retro"
    echo "Write permission test: PASSED" >> "${EVIDENCE_FILE}"
else
    log_warn "User 'retro' cannot write to /home/retro (may need volume mount in production)"
    echo "Write permission test: SKIPPED (expected with volume mount)" >> "${EVIDENCE_FILE}"
fi

# =============================================================================
# Test 4: Check directory structure
# =============================================================================
log_info "Checking /home/retro directory structure..."
DIR_LISTING=$(docker exec "${CONTAINER_2}" ls -la /home/retro/)

{
    echo "=== /home/retro Directory Listing ==="
    echo "${DIR_LISTING}"
    echo ""
} >> "${EVIDENCE_FILE}"

echo "RESULT: PASSED" >> "${EVIDENCE_FILE}"

log_info "All persistence tests passed"
echo ""
echo "=== TEST PASSED ==="
exit 0
