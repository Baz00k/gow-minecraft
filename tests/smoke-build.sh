#!/bin/bash -euo pipefail
# =============================================================================
# Smoke Test: Docker Build
# =============================================================================
# Tests that the Docker image builds successfully.
#
# Usage:
#   ./smoke-build.sh [build_context_dir]
#
# Environment Variables:
#   IMAGE_NAME    - Docker image name (default: gow-prism-offline:test)
#   BUILD_TIMEOUT - Build timeout in seconds (default: 600)
# =============================================================================

# Portable timeout fallback for macOS
if ! command -v timeout &>/dev/null; then
    timeout() {
        local duration="$1"
        shift
        # Simple fallback - just run the command without timeout on macOS
        # For full timeout support, install coreutils: brew install coreutils
        "$@"
    }
fi

IMAGE_NAME="${IMAGE_NAME:-gow-prism-offline:test}"
BUILD_TIMEOUT="${BUILD_TIMEOUT:-600}"
BUILD_CONTEXT="${1:-$(dirname "$0")/../build}"
PINS_FILE="${PINS_FILE:-$(dirname "$0")/../build/pins.env}"
EVIDENCE_DIR="$(dirname "$0")/../.sisyphus/evidence"
EVIDENCE_FILE="${EVIDENCE_DIR}/task-6-build.txt"

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
    echo "=== Smoke Test: Docker Build ==="
    echo "Timestamp: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    echo "Image: ${IMAGE_NAME}"
    echo "Build Context: ${BUILD_CONTEXT}"
    echo ""
} > "${EVIDENCE_FILE}"

# Verify build context exists
if [[ ! -d "${BUILD_CONTEXT}" ]]; then
    log_error "Build context directory not found: ${BUILD_CONTEXT}"
    echo "ERROR: Build context not found" >> "${EVIDENCE_FILE}"
    exit 1
fi

# Verify Dockerfile exists
if [[ ! -f "${BUILD_CONTEXT}/Dockerfile" ]]; then
    log_error "Dockerfile not found in ${BUILD_CONTEXT}"
    echo "ERROR: Dockerfile not found" >> "${EVIDENCE_FILE}"
    exit 1
fi

if [[ ! -f "${PINS_FILE}" ]]; then
    log_error "Pins file not found: ${PINS_FILE}"
    echo "ERROR: pins file not found" >> "${EVIDENCE_FILE}"
    exit 1
fi

set -a
source "${PINS_FILE}"
set +a

log_info "Building Docker image: ${IMAGE_NAME}"
log_info "Build context: ${BUILD_CONTEXT}"
log_info "Timeout: ${BUILD_TIMEOUT}s"

# Run the build with timeout
BUILD_START=$(date +%s)
BUILD_LOG=$(mktemp)

set +e
timeout "${BUILD_TIMEOUT}" docker build \
    --platform linux/amd64 \
    --build-arg BASE_APP_IMAGE="${BASE_APP_IMAGE}" \
    --build-arg PRISM_LAUNCHER_VERSION="${PRISM_LAUNCHER_VERSION}" \
    --build-arg PRISM_LAUNCHER_APPIMAGE_X86_64_URL="${PRISM_LAUNCHER_APPIMAGE_X86_64_URL}" \
    --build-arg PRISM_LAUNCHER_APPIMAGE_X86_64_SHA256="${PRISM_LAUNCHER_APPIMAGE_X86_64_SHA256}" \
    --build-arg PRISM_LAUNCHER_APPIMAGE_AARCH64_URL="${PRISM_LAUNCHER_APPIMAGE_AARCH64_URL}" \
    --build-arg PRISM_LAUNCHER_APPIMAGE_AARCH64_SHA256="${PRISM_LAUNCHER_APPIMAGE_AARCH64_SHA256}" \
    -t "${IMAGE_NAME}" \
    "${BUILD_CONTEXT}" 2>&1 | tee "${BUILD_LOG}"
BUILD_EXIT_CODE=${PIPESTATUS[0]}
set -e

BUILD_END=$(date +%s)
BUILD_DURATION=$((BUILD_END - BUILD_START))

# Append build log to evidence
{
    echo "=== Build Log ==="
    cat "${BUILD_LOG}"
    echo ""
    echo "=== Build Result ==="
    echo "Exit Code: ${BUILD_EXIT_CODE}"
    echo "Duration: ${BUILD_DURATION}s"
} >> "${EVIDENCE_FILE}"

# Cleanup temp file
rm -f "${BUILD_LOG}"

# Check build result
if [[ ${BUILD_EXIT_CODE} -eq 124 ]]; then
    log_error "Build timed out after ${BUILD_TIMEOUT}s"
    echo "RESULT: FAILED (timeout)" >> "${EVIDENCE_FILE}"
    exit 1
elif [[ ${BUILD_EXIT_CODE} -ne 0 ]]; then
    log_error "Build failed with exit code ${BUILD_EXIT_CODE}"
    echo "RESULT: FAILED" >> "${EVIDENCE_FILE}"
    exit 1
fi

# Verify the image was created
if ! docker image inspect "${IMAGE_NAME}" > /dev/null 2>&1; then
    log_error "Image ${IMAGE_NAME} not found after build"
    echo "RESULT: FAILED (image not found)" >> "${EVIDENCE_FILE}"
    exit 1
fi

# Get image size
IMAGE_SIZE=$(docker image inspect "${IMAGE_NAME}" --format='{{.Size}}')
IMAGE_SIZE_GB=$(echo "scale=2; ${IMAGE_SIZE} / 1024 / 1024 / 1024" | bc)

{
    echo "Image Size: ${IMAGE_SIZE_GB} GB (${IMAGE_SIZE} bytes)"
    echo "RESULT: PASSED"
} >> "${EVIDENCE_FILE}"

log_info "Build completed successfully in ${BUILD_DURATION}s"
log_info "Image size: ${IMAGE_SIZE_GB} GB"
echo ""
echo "=== TEST PASSED ==="
exit 0
