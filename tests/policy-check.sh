#!/bin/bash -euo pipefail
# =============================================================================
# Policy Check: Forbidden Sources and Unsafe Patterns
# =============================================================================
# Scans the codebase for policy violations:
# - Forbidden launcher names (TLauncher, SKLauncher)
# - Floating refs without digest pins
# - Binary downloads without checksums
# - Hardcoded credentials/secrets
#
# Usage:
#   ./tests/policy-check.sh [--strict]
#
# Options:
#   --strict    Fail on warnings (default: only fail on errors)
#
# Exit Codes:
#   0 - All checks passed
#   1 - Policy violations found
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
STRICT_MODE="${1:-}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
ERRORS=0
WARNINGS=0

# Log functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
    ((ERRORS++)) || true
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
    ((WARNINGS++)) || true
}

log_pass() {
    echo -e "${GREEN}[PASS]${NC} $*"
}

# =============================================================================
# Check 1: Forbidden Launcher Names
# =============================================================================
# Scans for references to banned launchers (TLauncher, SKLauncher)
# Excludes documentation files that legitimately discuss these as forbidden
# =============================================================================

check_forbidden_launchers() {
    log_info "Checking for forbidden launcher references..."

    local found_violations=0

    # Files to exclude from this check (documentation that lists forbidden items)
    local exclude_patterns=(
        "LEGAL\.md"
        "PINNING_POLICY\.md"
        "policy-check\.sh"  # Don't flag ourselves
        "policy\.yml"       # Workflow file documenting forbidden items
    )

    # Build grep exclude pattern
    local exclude_args=""
    for pattern in "${exclude_patterns[@]}"; do
        exclude_args="${exclude_args} --exclude=${pattern}"
    done

    # Check for TLauncher (case-insensitive)
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

    # Check for SKLauncher (case-insensitive)
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

# =============================================================================
# Check 2: Floating Refs Without Digest
# =============================================================================
# Checks Dockerfiles and pins.env for image references without digest pins
# Pattern: FROM image:tag without @sha256:digest
# =============================================================================

check_floating_refs() {
    log_info "Checking for floating image references..."

    local found_violations=0

    # Check Dockerfiles
    while IFS= read -r file; do
        if [[ -f "${file}" ]]; then
            # Look for FROM statements with :edge or :latest that don't have @sha256
            while IFS= read -r line; do
                if [[ -n "${line}" ]]; then
                    local linenum content
                    linenum=$(echo "${line}" | cut -d: -f1)
                    content=$(echo "${line}" | cut -d: -f2-)
                    
                    # Check for floating refs (FROM with :edge or :latest but no @sha256)
                    if echo "${content}" | grep -qiE 'FROM.*:(edge|latest)' && \
                       ! echo "${content}" | grep -q '@sha256:'; then
                        # Allow if it's using a build arg for the base image (common pattern)
                        if ! echo "${content}" | grep -q '\${BASE_APP_IMAGE}'; then
                            log_error "Floating ref in ${file}:${linenum} - missing digest pin"
                            ((found_violations++)) || true
                        fi
                    fi
                fi
            done < <(grep -n 'FROM' "${file}" 2>/dev/null || true)
        fi
    done < <(find "${PROJECT_ROOT}" -name "Dockerfile*" -o -name "*.dockerfile" 2>/dev/null | grep -v '.git')

    # Check pins.env for floating refs (base image should have digest)
    local pins_env="${PROJECT_ROOT}/build/pins.env"
    if [[ -f "${pins_env}" ]]; then
        # Check BASE_APP_IMAGE has digest
        if grep -q 'BASE_APP_IMAGE=' "${pins_env}"; then
            local base_image
            base_image=$(grep 'BASE_APP_IMAGE=' "${pins_env}" | head -1 | cut -d= -f2-)
            
            # Should have @sha256: in the value
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

# =============================================================================
# Check 3: Binary Downloads Without Checksums
# =============================================================================
# Checks for curl/wget downloads that aren't followed by checksum verification
# =============================================================================

check_unverified_downloads() {
    log_info "Checking for unverified binary downloads..."

    local found_violations=0

    # Check Dockerfiles for curl/wget without subsequent sha256sum
    while IFS= read -r file; do
        if [[ -f "${file}" ]]; then
            local content
            content=$(cat "${file}")
            
            # Look for curl/wget downloads
            if echo "${content}" | grep -qE '(curl|wget).*(-o|-O|>)'; then
                # Check if there's a sha256sum or sha256 verification
                if ! echo "${content}" | grep -qE '(sha256sum|sha256).*(-c|--check)'; then
                    # Only warn, not error - some downloads may be from trusted sources
                    log_warn "Potential unverified download in ${file} - ensure checksums are verified"
                    ((found_violations++)) || true
                fi
            fi
        fi
    done < <(find "${PROJECT_ROOT}" -name "Dockerfile*" -o -name "*.dockerfile" 2>/dev/null | grep -v '.git')

    # Check shell scripts
    while IFS= read -r file; do
        if [[ -f "${file}" ]]; then
            local content
            content=$(cat "${file}")
            
            # Look for curl/wget downloads of binaries
            if echo "${content}" | grep -qE '(curl|wget).*(-o|-O|>)'; then
                # Check if there's a checksum verification
                if ! echo "${content}" | grep -qE '(sha256sum|sha256|md5sum).*(-c|--check)'; then
                    # Skip this script itself and known safe scripts
                    local basename
                    basename=$(basename "${file}")
                    if [[ "${basename}" != "policy-check.sh" ]] && [[ "${basename}" != "run-all-smoke.sh" ]]; then
                        log_warn "Potential unverified download in ${file} - consider adding checksum verification"
                        ((found_violations++)) || true
                    fi
                fi
            fi
        fi
    done < <(find "${PROJECT_ROOT}" -name "*.sh" 2>/dev/null | grep -v '.git' | grep -v 'node_modules')

    if [[ ${found_violations} -eq 0 ]]; then
        log_pass "All downloads appear to be verified with checksums"
    fi
}

# =============================================================================
# Check 4: Hardcoded Credentials/Secrets
# =============================================================================
# Scans for common secret patterns
# =============================================================================

check_secrets() {
    log_info "Checking for hardcoded credentials and secrets..."

    local found_violations=0

    # Patterns to detect (excluding documentation)
    local secret_patterns=(
        'password\s*=\s*["\x27][^"\x27]+["\x27]'
        'api_key\s*=\s*["\x27][^"\x27]+["\x27]'
        'secret\s*=\s*["\x27][^"\x27]+["\x27]'
        'token\s*=\s*["\x27][^"\x27]+["\x27]'
        'AWS_[A-Z_]+\s*=\s*["\x27][A-Za-z0-9+/]{20,}["\x27]'
    )

    # Files to exclude
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
                
                # Skip excluded files
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
            --include="Dockerfile*" --include="*.dockerfile" \
            . 2>/dev/null || true)
    done

    # Check for .env files with actual values (should be in .gitignore)
    while IFS= read -r envfile; do
        if [[ -f "${envfile}" ]]; then
            # Check if it's a template file (contains placeholder values)
            local content
            content=$(cat "${envfile}")
            
            if ! echo "${content}" | grep -qE '(\$\{|<|your_|placeholder|example|XXX)'; then
                log_warn ".env file may contain real values: ${envfile} - ensure it's in .gitignore"
                ((found_violations++)) || true
            fi
        fi
    done < <(find "${PROJECT_ROOT}" -name "*.env" -o -name ".env*" 2>/dev/null | grep -v '.git' | grep -v 'pins.env' | grep -v 'args.env')
    if [[ ${found_violations} -eq 0 ]]; then
        log_pass "No hardcoded secrets detected"
    fi
}

# =============================================================================
# Main
# =============================================================================

main() {
    echo "=============================================="
    echo "Policy Check: Forbidden Sources & Unsafe Patterns"
    echo "=============================================="
    echo ""
    echo "Project root: ${PROJECT_ROOT}"
    echo ""

    # Run all checks
    check_forbidden_launchers
    echo ""
    
    check_floating_refs
    echo ""
    
    check_unverified_downloads
    echo ""
    
    check_secrets
    echo ""

    # Summary
    echo "=============================================="
    echo "Summary"
    echo "=============================================="
    echo -e "Errors:   ${RED}${ERRORS}${NC}"
    echo -e "Warnings: ${YELLOW}${WARNINGS}${NC}"
    echo ""

    # Exit logic
    if [[ ${ERRORS} -gt 0 ]]; then
        log_error "Policy check failed with ${ERRORS} error(s)"
        exit 1
    fi

    if [[ "${STRICT_MODE}" == "--strict" ]] && [[ ${WARNINGS} -gt 0 ]]; then
        log_warn "Policy check failed with ${WARNINGS} warning(s) (strict mode)"
        exit 1
    fi

    if [[ ${WARNINGS} -gt 0 ]]; then
        log_warn "Policy check passed with ${WARNINGS} warning(s)"
        echo "  Run with --strict to fail on warnings"
    else
        log_pass "All policy checks passed"
    fi

    exit 0
}

main
