#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
STRICT_MODE="${1:-}"
RESULTS_DIR="${RESULTS_DIR:-${PROJECT_ROOT}/test-results/evidence}"
RESULTS_FILE="${RESULTS_DIR}/policy-check.txt"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

ERRORS=0
WARNINGS=0

mkdir -p "${RESULTS_DIR}"

log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
    echo "[INFO] $*" >> "${RESULTS_FILE}"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
    echo "[ERROR] $*" >> "${RESULTS_FILE}"
    ((ERRORS++)) || true
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
    echo "[WARN] $*" >> "${RESULTS_FILE}"
    ((WARNINGS++)) || true
}

log_pass() {
    echo -e "${GREEN}[PASS]${NC} $*"
    echo "[PASS] $*" >> "${RESULTS_FILE}"
}

check_forbidden_launchers() {
    log_info "Checking for forbidden launcher references..."

    local found_violations=0
    local exclude_patterns=(
        "LEGAL\.md"
        "PINNING_POLICY\.md"
        "policy-check\.sh"
        "policy\.yml"
    )

    local exclude_args=""
    for pattern in "${exclude_patterns[@]}"; do
        exclude_args="${exclude_args} --exclude=${pattern}"
    done

    while IFS= read -r match; do
        if [[ -n "${match}" ]]; then
            log_error "Forbidden launcher 'TLauncher' found: ${match}"
            ((found_violations++)) || true
        fi
    done < <(cd "${PROJECT_ROOT}" && grep -ri "tlauncher" \
        --include="*.sh" --include="*.py" --include="*.js" --include="*.ts" \
        --include="*.json" --include="*.yaml" --include="*.yml" \
        --include="*.env" --include="Dockerfile*" --include="*.dockerfile" \
        --include="*.toml" --include="*.cfg" --include="*.conf" \
        ${exclude_args} . 2>/dev/null || true)

    while IFS= read -r match; do
        if [[ -n "${match}" ]]; then
            log_error "Forbidden launcher 'SKLauncher' found: ${match}"
            ((found_violations++)) || true
        fi
    done < <(cd "${PROJECT_ROOT}" && grep -ri "sklauncher" \
        --include="*.sh" --include="*.py" --include="*.js" --include="*.ts" \
        --include="*.json" --include="*.yaml" --include="*.yml" \
        --include="*.env" --include="Dockerfile*" --include="*.dockerfile" \
        --include="*.toml" --include="*.cfg" --include="*.conf" \
        ${exclude_args} . 2>/dev/null || true)

    if [[ ${found_violations} -eq 0 ]]; then
        log_pass "No forbidden launcher references found"
    fi
}

check_floating_refs() {
    log_info "Checking for floating image references..."

    local found_violations=0

    while IFS= read -r file; do
        if [[ -f "${file}" ]]; then
            while IFS= read -r line; do
                if [[ -n "${line}" ]]; then
                    local linenum content
                    linenum=$(echo "${line}" | cut -d: -f1)
                    content=$(echo "${line}" | cut -d: -f2-)

                    if echo "${content}" | grep -qiE 'FROM.*:(edge|latest)' && \
                       ! echo "${content}" | grep -q '@sha256:'; then
                        if ! echo "${content}" | grep -q '\${BASE_APP_IMAGE}'; then
                            log_error "Floating ref in ${file}:${linenum} - missing digest pin"
                            ((found_violations++)) || true
                        fi
                    fi
                fi
            done < <(grep -n 'FROM' "${file}" 2>/dev/null || true)
        fi
    done < <(find "${PROJECT_ROOT}" -name "Dockerfile*" -o -name "*.dockerfile" 2>/dev/null | grep -v '.git')

    local pins_env="${PROJECT_ROOT}/build/pins.env"
    if [[ -f "${pins_env}" ]]; then
        if grep -q 'BASE_APP_IMAGE=' "${pins_env}"; then
            local base_image
            base_image=$(grep 'BASE_APP_IMAGE=' "${pins_env}" | head -1 | cut -d= -f2-)
            if [[ "${base_image}" == *":edge"* ]] && [[ "${base_image}" != *"@sha256:"* ]]; then
                log_error "BASE_APP_IMAGE in pins.env uses floating ref without digest: ${base_image}"
                ((found_violations++)) || true
            fi
        fi
    fi

    if [[ ${found_violations} -eq 0 ]]; then
        log_pass "All image references are properly pinned"
    fi
}

check_unverified_downloads() {
    log_info "Checking for unverified binary downloads..."

    local found_warnings=0

    while IFS= read -r file; do
        if [[ -f "${file}" ]]; then
            local content
            content=$(cat "${file}")
            if echo "${content}" | grep -qE '(curl|wget).*(-o|-O|>)'; then
                if ! echo "${content}" | grep -qE '(sha256sum|sha256).*(-c|--check)'; then
                    log_warn "Potential unverified download in ${file}"
                    ((found_warnings++)) || true
                fi
            fi
        fi
    done < <(find "${PROJECT_ROOT}" -name "Dockerfile*" -o -name "*.dockerfile" 2>/dev/null | grep -v '.git')

    while IFS= read -r file; do
        if [[ -f "${file}" ]]; then
            local content
            content=$(cat "${file}")
            if echo "${content}" | grep -qE '(curl|wget).*(-o|-O|>)'; then
                if ! echo "${content}" | grep -qE '(sha256sum|sha256|md5sum).*(-c|--check)'; then
                    local basename
                    basename=$(basename "${file}")
                    if [[ "${basename}" != "policy-check.sh" ]] && [[ "${basename}" != "run-all-smoke.sh" ]]; then
                        log_warn "Potential unverified download in ${file}"
                        ((found_warnings++)) || true
                    fi
                fi
            fi
        fi
    done < <(find "${PROJECT_ROOT}" -name "*.sh" 2>/dev/null | grep -v '.git' | grep -v 'node_modules')

    if [[ ${found_warnings} -eq 0 ]]; then
        log_pass "All downloads appear to be verified with checksums"
    fi
}

check_secrets() {
    log_info "Checking for hardcoded credentials and secrets..."

    local found_violations=0
    local secret_patterns=(
        'password\s*=\s*["\x27][^"\x27]+["\x27]'
        'api_key\s*=\s*["\x27][^"\x27]+["\x27]'
        'secret\s*=\s*["\x27][^"\x27]+["\x27]'
        'token\s*=\s*["\x27][^"\x27]+["\x27]'
        'AWS_[A-Z_]+\s*=\s*["\x27][A-Za-z0-9+/]{20,}["\x27]'
    )
    local exclude_files=(
        "policy-check.sh"
        "LEGAL.md"
        "PINNING_POLICY.md"
        "README.md"
    )

    for pattern in "${secret_patterns[@]}"; do
        while IFS= read -r match; do
            if [[ -n "${match}" ]]; then
                local filename
                filename=$(echo "${match}" | cut -d: -f1)
                local basename
                basename=$(basename "${filename}")

                local skip=false
                for excluded in "${exclude_files[@]}"; do
                    if [[ "${basename}" == "${excluded}" ]]; then
                        skip=true
                        break
                    fi
                done

                if [[ "${skip}" == "false" ]]; then
                    log_error "Potential hardcoded secret found: ${match}"
                    ((found_violations++)) || true
                fi
            fi
        done < <(cd "${PROJECT_ROOT}" && grep -riE "${pattern}" \
            --include="*.sh" --include="*.py" --include="*.js" --include="*.ts" \
            --include="*.env" --include="*.yaml" --include="*.yml" \
            --include="Dockerfile*" --include="*.dockerfile" . 2>/dev/null || true)
    done

    while IFS= read -r envfile; do
        if [[ -f "${envfile}" ]]; then
            local content
            content=$(cat "${envfile}")
            if ! echo "${content}" | grep -qE '(\$\{|<|your_|placeholder|example|XXX)'; then
                log_warn ".env file may contain real values: ${envfile}"
                ((found_violations++)) || true
            fi
        fi
    done < <(find "${PROJECT_ROOT}" -name "*.env" -o -name ".env*" 2>/dev/null | grep -v '.git' | grep -v 'pins.env' | grep -v 'args.env')

    if [[ ${found_violations} -eq 0 ]]; then
        log_pass "No hardcoded secrets detected"
    fi
}

main() {
    {
        echo "=== Policy Check ==="
        echo "Timestamp: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
        echo "Project root: ${PROJECT_ROOT}"
        echo "Strict mode: ${STRICT_MODE:-false}"
        echo ""
    } > "${RESULTS_FILE}"

    echo "=============================================="
    echo "Policy Check: Forbidden Sources & Unsafe Patterns"
    echo "=============================================="
    echo ""
    echo "Project root: ${PROJECT_ROOT}"
    echo ""

    check_forbidden_launchers
    echo ""
    check_floating_refs
    echo ""
    check_unverified_downloads
    echo ""
    check_secrets
    echo ""

    echo "=============================================="
    echo "Summary"
    echo "=============================================="
    echo -e "Errors:   ${RED}${ERRORS}${NC}"
    echo -e "Warnings: ${YELLOW}${WARNINGS}${NC}"
    echo ""

    {
        echo "=== Summary ==="
        echo "Errors: ${ERRORS}"
        echo "Warnings: ${WARNINGS}"
    } >> "${RESULTS_FILE}"

    if [[ ${ERRORS} -gt 0 ]]; then
        log_error "Policy check failed with ${ERRORS} error(s)"
        echo "RESULT: FAILED" >> "${RESULTS_FILE}"
        exit 1
    fi

    if [[ "${STRICT_MODE}" == "--strict" ]] && [[ ${WARNINGS} -gt 0 ]]; then
        log_warn "Policy check failed with ${WARNINGS} warning(s) (strict mode)"
        echo "RESULT: FAILED" >> "${RESULTS_FILE}"
        exit 1
    fi

    if [[ ${WARNINGS} -gt 0 ]]; then
        log_warn "Policy check passed with ${WARNINGS} warning(s)"
        echo "  Run with --strict to fail on warnings"
    else
        log_pass "All policy checks passed"
    fi

    echo "RESULT: PASSED" >> "${RESULTS_FILE}"
    exit 0
}

main
