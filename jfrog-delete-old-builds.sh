#!/bin/bash

#
# JFrog API Script: Delete Old Builds by Naming Pattern
# This script deletes builds from JFrog Artifactory that match a naming pattern
# and are older than a specified number of days.
# Compatible with macOS (BSD) and Linux
# Requires: jq, curl, bash
#

set -euo pipefail

# Configuration
JFROG_URL="${JFROG_URL:-https://artifactory.example.com}"
JFROG_USERNAME="${JFROG_USERNAME:-}"
JFROG_API_KEY="${JFROG_API_KEY:-}"
BUILD_PATTERN="${BUILD_PATTERN:-}"
DAYS_OLD="${DAYS_OLD:-30}"
DRY_RUN="${DRY_RUN:-false}"
DEBUG="${DEBUG:-false}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions - all output to stderr to preserve stdout for data
log_info() {
    echo -e "${BLUE}[INFO]${NC} $*" >&2
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*" >&2
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*" >&2
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

log_debug() {
    if [[ "$DEBUG" == "true" ]]; then
        echo -e "${BLUE}[DEBUG]${NC} $*" >&2
    fi
}

# Check if required tools are installed
check_requirements() {
    local missing_tools=()
    
    command -v jq &> /dev/null || missing_tools+=("jq")
    command -v curl &> /dev/null || missing_tools+=("curl")
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        log_error "Please install them and try again"
        exit 1
    fi
}

# Detect if running on macOS or Linux
is_mac() {
    [[ "$OSTYPE" == "darwin"* ]]
}

# Validate required environment variables
validate_config() {
    local missing_vars=()
    
    [[ -z "$JFROG_URL" ]] && missing_vars+=("JFROG_URL")
    [[ -z "$JFROG_USERNAME" ]] && missing_vars+=("JFROG_USERNAME")
    [[ -z "$JFROG_API_KEY" ]] && missing_vars+=("JFROG_API_KEY")
    [[ -z "$BUILD_PATTERN" ]] && missing_vars+=("BUILD_PATTERN")
    
    if [[ ${#missing_vars[@]} -gt 0 ]]; then
        log_error "Missing required environment variables: ${missing_vars[*]}"
        print_usage
        exit 1
    fi
}

# Print usage information
print_usage() {
    cat << EOF
Usage: $0

Required Environment Variables:
    JFROG_URL           - JFrog Artifactory URL (e.g., https://artifactory.example.com)
    JFROG_USERNAME      - JFrog username
    JFROG_API_KEY       - JFrog API key or password
    BUILD_PATTERN       - Regex pattern to match build names (e.g., "myapp-.*")

Optional Environment Variables:
    DAYS_OLD            - Delete builds older than this many days (default: 30)
    DRY_RUN             - Set to 'true' to preview deletions without executing (default: false)
    DEBUG               - Set to 'true' for debug output (default: false)

Examples:
    # Delete builds older than 30 days matching pattern "myapp-.*"
    JFROG_URL="https://artifactory.example.com" \\
    JFROG_USERNAME="admin" \\
    JFROG_API_KEY="your-api-key" \\
    BUILD_PATTERN="myapp-.*" \\
    $0

    # Dry run for builds matching "test-.*" older than 60 days
    JFROG_URL="https://artifactory.example.com" \\
    JFROG_USERNAME="admin" \\
    JFROG_API_KEY="your-api-key" \\
    BUILD_PATTERN="test-.*" \\
    DAYS_OLD="60" \\
    DRY_RUN="true" \\
    $0

    # Debug mode to see API responses
    JFROG_URL="https://artifactory.example.com" \\
    JFROG_USERNAME="admin" \\
    JFROG_API_KEY="your-api-key" \\
    BUILD_PATTERN="myapp-.*" \\
    DEBUG="true" \\
    $0

EOF
}

# Get list of builds from JFrog
get_builds() {
    local pattern=$1
    local url="${JFROG_URL}/api/builds"
    
    log_info "Fetching builds from JFrog..."
    
    response=$(curl -s -w "\n%{http_code}" -u "${JFROG_USERNAME}:${JFROG_API_KEY}" \
        -H "Content-Type: application/json" \
        "$url" 2>&1)
    
    local http_code=$(echo "$response" | tail -n1)
    local body=$(echo "$response" | sed '$d')
    
    if [[ $http_code != "200" ]]; then
        log_error "Failed to fetch builds (HTTP $http_code): $body"
        return 1
    fi
    
    log_debug "Builds API response: $body"
    
    # Parse JSON with jq - filter by pattern on buildName field
    echo "$body" | jq -r '.data[] | select(.buildName | test("'"$pattern"'")) | .buildName' || true
}

# Get build numbers for a given build name
get_build_numbers() {
    local build_name=$1
    local url="${JFROG_URL}/api/build/${build_name}"
    
    response=$(curl -s -w "\n%{http_code}" -u "${JFROG_USERNAME}:${JFROG_API_KEY}" \
        -H "Content-Type: application/json" \
        "$url" 2>&1)
    
    local http_code=$(echo "$response" | tail -n1)
    local body=$(echo "$response" | sed '$d')
    
    if [[ $http_code != "200" ]]; then
        log_error "Failed to fetch build numbers for $build_name (HTTP $http_code): $body"
        return 1
    fi
    
    log_debug "Build numbers API response for $build_name: $body"
    
    # Extract build numbers from uri field - remove leading slash
    echo "$body" | jq -r '.buildsNumbers[]?.uri | ltrimstr("/")' || true
}

# Get build information for a specific build number
get_build_info() {
    local build_name=$1
    local build_number=$2
    local url="${JFROG_URL}/api/build/${build_name}/${build_number}"
    
    response=$(curl -s -w "\n%{http_code}" -u "${JFROG_USERNAME}:${JFROG_API_KEY}" \
        -H "Content-Type: application/json" \
        "$url" 2>&1)
    
    local http_code=$(echo "$response" | tail -n1)
    local body=$(echo "$response" | sed '$d')
    
    if [[ $http_code != "200" ]]; then
        log_error "Failed to fetch build info for $build_name/$build_number (HTTP $http_code): $body"
        return 1
    fi
    
    log_debug "Build info API response for $build_name/$build_number: $body"
    
    # Extract the started timestamp using jq
    echo "$body" | jq -r '.buildInfo.started // empty' || true
}

# Convert ISO 8601 timestamp to Unix timestamp (macOS and Linux compatible)
to_unix_timestamp() {
    local iso_timestamp=$1
    
    if is_mac; then
        # macOS: use -jf for input format
        # Handle format: 2026-03-04T07:46:47.554+0000 (milliseconds)
        # Strip milliseconds and parse without them
        local timestamp_no_ms="${iso_timestamp%.*}+0000"
        date -jf "%Y-%m-%dT%H:%M:%S+0000" "$timestamp_no_ms" +%s 2>/dev/null || \
        date -jf "%Y-%m-%dT%H:%M:%SZ" "$iso_timestamp" +%s 2>/dev/null || \
        echo ""
    else
        # Linux: use -d for date string parsing
        date -d "$iso_timestamp" +%s 2>/dev/null || \
        echo ""
    fi
}

# Get current Unix timestamp (cross-platform)
get_current_timestamp() {
    date +%s
}

# Check if build is older than specified days
is_build_old() {
    local timestamp=$1
    local days=$2
    
    if [[ -z "$timestamp" ]]; then
        return 1
    fi
    
    local build_timestamp
    build_timestamp=$(to_unix_timestamp "$timestamp")
    if [[ -z "$build_timestamp" ]]; then
        log_warn "Could not parse timestamp: $timestamp"
        return 1
    fi
    
    local current_timestamp
    current_timestamp=$(get_current_timestamp)
    local age_seconds=$((current_timestamp - build_timestamp))
    local age_days=$((age_seconds / 86400))
    
    log_info "Build age: $age_days days (threshold: $days days)"
    [[ $age_days -gt $days ]]
}

# Delete a build
delete_build() {
    local build_name=$1
    local build_number=$2
    local url="${JFROG_URL}/api/build/${build_name}?buildNumbers=${build_number}&deleteArtifacts=1"
    
    log_info "Deleting build: $build_name/$build_number"
    
    response=$(curl -s -w "\n%{http_code}" -X DELETE \
        -u "${JFROG_USERNAME}:${JFROG_API_KEY}" \
        -H "Content-Type: application/json" \
        "$url" 2>&1)
    
    local http_code=$(echo "$response" | tail -n1)
    
    if [[ $http_code == "204" ]] || [[ $http_code == "200" ]]; then
        log_success "Successfully deleted: $build_name/$build_number"
        return 0
    else
        log_error "Failed to delete build $build_name/$build_number (HTTP $http_code)"
        return 1
    fi
}

# Main execution
main() {
    check_requirements
    validate_config
    
    log_info "Starting JFrog build cleanup script"
    log_info "Platform: $(is_mac && echo 'macOS' || echo 'Linux')"
    log_info "URL: $JFROG_URL"
    log_info "Pattern: $BUILD_PATTERN"
    log_info "Days old threshold: $DAYS_OLD"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_warn "Running in DRY RUN mode - no builds will be deleted"
    fi
    
    if [[ "$DEBUG" == "true" ]]; then
        log_warn "Debug mode enabled - API responses will be logged"
    fi
    
    local builds
    builds=$(get_builds "$BUILD_PATTERN")
    
    if [[ -z "$builds" ]]; then
        log_warn "No builds found matching pattern: $BUILD_PATTERN"
        exit 0
    fi
    
    local deleted_count=0
    local skipped_count=0
    
    while IFS= read -r build_name; do
        [[ -z "$build_name" ]] && continue
        
        log_info "Processing build: $build_name"
        
        local build_numbers
        build_numbers=$(get_build_numbers "$build_name")
        
        if [[ -z "$build_numbers" ]]; then
            log_warn "No build numbers found for: $build_name"
            continue
        fi
        
        while IFS= read -r build_number; do
            [[ -z "$build_number" ]] && continue
            
            log_info "Checking build: $build_name/$build_number"
            local timestamp
            timestamp=$(get_build_info "$build_name" "$build_number")
            
            if [[ -z "$timestamp" ]]; then
                log_warn "Skipping build due to API error: $build_name/$build_number"
                continue
            fi
            
            if is_build_old "$timestamp" "$DAYS_OLD"; then
                log_info "Build is older than $DAYS_OLD days: $build_name/$build_number (modified: $timestamp)"
                
                if [[ "$DRY_RUN" == "true" ]]; then
                    log_warn "[DRY RUN] Would delete: $build_name/$build_number"
                else
                    if delete_build "$build_name" "$build_number"; then
                        ((deleted_count++))
                    fi
                fi
            else
                log_info "Build is recent, skipping: $build_name/$build_number (modified: $timestamp)"
                ((skipped_count++))
            fi
        done <<< "$build_numbers"
    done <<< "$builds"
    
    log_info "Cleanup complete"
    log_info "Deleted: $deleted_count builds"
    log_info "Skipped: $skipped_count builds"
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
