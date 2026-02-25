#!/bin/bash
set -euo pipefail
# =============================================================================
# Smoke Test: Container Startup
# =============================================================================
# Tests that container starts and the startup script is present.
#
# Usage:
#   ./smoke-startup.sh
#
# Environment Variables:
#   IMAGE_NAME      - Docker image name (default: gow-prism-offline:test)
#   CONTAINER_NAME  - Test container name (default: smoke-test-startup)
#   STARTUP_TIMEOUT - Container start timeout in seconds (default: 30)
# =============================================================================

IMAGE_NAME="${IMAGE_NAME:-gow-prism-offline:test}"
CONTAINER_NAME="${CONTAINER_NAME:-smoke-test-startup}"
STARTUP_TIMEOUT="${STARTUP_TIMEOUT:-30}"
EVIDENCE_DIR="$(dirname "$0")/../.sisyphus/evidence"
EVIDENCE_FILE="${EVIDENCE_DIR}/task-6-startup.txt"

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

# Initialize evidence file
{
    echo "=== Smoke Test: Container Startup ==="
    echo "Timestamp: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    echo "Image: ${IMAGE_NAME}"
    echo "Container: ${CONTAINER_NAME}"
    echo ""
} > "${EVIDENCE_FILE}"

# Cleanup function
cleanup() {
    log_info "Cleaning up container ${CONTAINER_NAME}..."
    docker rm -f "${CONTAINER_NAME}" 2>/dev/null || true
}
trap cleanup EXIT

# Verify image exists
if ! docker image inspect "${IMAGE_NAME}" > /dev/null 2>&1; then
    log_error "Image ${IMAGE_NAME} not found. Run smoke-build.sh first."
    echo "ERROR: Image not found" >> "${EVIDENCE_FILE}"
    exit 1
fi

# Test 1: Container can be created and started
log_info "Starting container with sleep command..."
set +e
docker run -d --name "${CONTAINER_NAME}" "${IMAGE_NAME}" sleep infinity
RUN_EXIT_CODE=$?
set -e

if [[ ${RUN_EXIT_CODE} -ne 0 ]]; then
    log_error "Failed to start container"
    echo "RESULT: FAILED (container start)" >> "${EVIDENCE_FILE}"
    exit 1
fi

# Wait for container to be running
log_info "Waiting for container to be running..."
sleep 2

CONTAINER_STATUS=$(docker inspect --format='{{.State.Status}}' "${CONTAINER_NAME}")
if [[ "${CONTAINER_STATUS}" != "running" ]]; then
    log_error "Container is not running. Status: ${CONTAINER_STATUS}"
    echo "RESULT: FAILED (container not running)" >> "${EVIDENCE_FILE}"
    exit 1
fi

log_info "Container is running"

# Test 2: Startup script exists at expected location
log_info "Checking for startup script at /opt/gow/startup-app.sh..."
STARTUP_SCRIPT_EXISTS=$(docker exec "${CONTAINER_NAME}" test -f /opt/gow/startup-app.sh && echo "yes" || echo "no")

if [[ "${STARTUP_SCRIPT_EXISTS}" != "yes" ]]; then
    log_error "Startup script not found at /opt/gow/startup-app.sh"
    echo "RESULT: FAILED (startup script missing)" >> "${EVIDENCE_FILE}"
    exit 1
fi

log_info "Startup script found"

# Test 3: Startup script is executable
log_info "Checking startup script permissions..."
SCRIPT_PERMS=$(docker exec "${CONTAINER_NAME}" stat -c "%a" /opt/gow/startup-app.sh)
log_info "Startup script permissions: ${SCRIPT_PERMS}"

# Check if executable (any executable bit)
if [[ $((SCRIPT_PERMS & 1)) -eq 0 ]] && [[ $((SCRIPT_PERMS & 10)) -eq 0 ]] && [[ $((SCRIPT_PERMS & 100)) -eq 0 ]]; then
    log_error "Startup script is not executable"
    echo "RESULT: FAILED (startup script not executable)" >> "${EVIDENCE_FILE}"
    exit 1
fi

# Test 4: Startup script has valid shebang
log_info "Checking startup script shebang..."
SHEBANG=$(docker exec "${CONTAINER_NAME}" head -1 /opt/gow/startup-app.sh)
{
    echo "=== Startup Script Info ==="
    echo "Permissions: ${SCRIPT_PERMS}"
    echo "Shebang: ${SHEBANG}"
} >> "${EVIDENCE_FILE}"

if [[ ! "${SHEBANG}" =~ ^#!.*bash ]]; then
    log_error "Startup script does not have bash shebang: ${SHEBANG}"
    echo "RESULT: FAILED (invalid shebang)" >> "${EVIDENCE_FILE}"
    exit 1
fi

# Test 5: Check for required GoW utilities
log_info "Checking for GoW utilities..."
GOW_UTILS_EXISTS=$(docker exec "${CONTAINER_NAME}" test -f /opt/gow/bash-lib/utils.sh && echo "yes" || echo "no")
LAUNCH_COMP_EXISTS=$(docker exec "${CONTAINER_NAME}" test -f /opt/gow/launch-comp.sh && echo "yes" || echo "no")

{
    echo "=== GoW Utilities ==="
    echo "utils.sh: ${GOW_UTILS_EXISTS}"
    echo "launch-comp.sh: ${LAUNCH_COMP_EXISTS}"
} >> "${EVIDENCE_FILE}"

if [[ "${GOW_UTILS_EXISTS}" != "yes" ]]; then
    log_warn "GoW utils.sh not found (may be expected in base image)"
fi

if [[ "${LAUNCH_COMP_EXISTS}" != "yes" ]]; then
    log_warn "GoW launch-comp.sh not found (may be expected in base image)"
fi

# Test 6: Check XDG_RUNTIME_DIR environment variable
log_info "Checking XDG_RUNTIME_DIR environment variable..."
XDG_RUNTIME=$(docker exec "${CONTAINER_NAME}" printenv XDG_RUNTIME_DIR)
{
    echo "=== Environment ==="
    echo "XDG_RUNTIME_DIR: ${XDG_RUNTIME}"
} >> "${EVIDENCE_FILE}"

if [[ "${XDG_RUNTIME}" != "/tmp/.X11-unix" ]]; then
    log_error "XDG_RUNTIME_DIR is not set correctly: ${XDG_RUNTIME}"
    echo "RESULT: FAILED (XDG_RUNTIME_DIR)" >> "${EVIDENCE_FILE}"
    exit 1
fi

echo "RESULT: PASSED" >> "${EVIDENCE_FILE}"

log_info "All startup tests passed"
echo ""
echo "=== TEST PASSED ==="
exit 0
