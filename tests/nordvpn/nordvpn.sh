#!/bin/bash

#---------------------------------------------------------------------------------
# NordVPN Installation Test Suite
#
# Uses Docker to test the install script across multiple Linux distributions.
# Pulls each distro image, runs the install script, and reports results.
#
# Usage:
#   ./tests/nordvpn/nordvpn.sh              # Run all tests
#   ./tests/nordvpn/nordvpn.sh --parallel 4 # Run 4 tests in parallel
#   ./tests/nordvpn/nordvpn.sh --filter deb  # Only test distros matching "deb"
#---------------------------------------------------------------------------------

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
INSTALL_SCRIPT="${PROJECT_ROOT}/install/nordvpn/install-nordvpn.sh"
LOG_DIR="${SCRIPT_DIR}/logs"
PARALLEL=1
FILTER=""
TIMEOUT=300 # 5 minutes per container

#---------------------------------------------------------------------------------
# Colors
#---------------------------------------------------------------------------------

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

#---------------------------------------------------------------------------------
# Distribution test matrix
# Format: "docker_image|label|family"
#   family: apt, dnf, yum, zypper, pacman
#---------------------------------------------------------------------------------

DISTROS=(
    # Debian-based (APT)
    "debian:11|Debian 11 (Bullseye)|apt"
    "debian:12|Debian 12 (Bookworm)|apt"
    "ubuntu:20.04|Ubuntu 20.04 LTS|apt"
    "ubuntu:22.04|Ubuntu 22.04 LTS|apt"
    "ubuntu:24.04|Ubuntu 24.04 LTS|apt"
    "kalilinux/kali-rolling|Kali Linux (Rolling)|apt"

    # RPM-based (DNF)
    "fedora:39|Fedora 39|dnf"
    "fedora:40|Fedora 40|dnf"
    "fedora:41|Fedora 41|dnf"

    # RPM-based (YUM)
    "rockylinux:8|Rocky Linux 8|yum"
    "rockylinux:9|Rocky Linux 9|yum"
    "almalinux:8|AlmaLinux 8|yum"
    "almalinux:9|AlmaLinux 9|yum"

    # Zypper-based
    "opensuse/leap:15.6|openSUSE Leap 15.6|zypper"
    "opensuse/tumbleweed|openSUSE Tumbleweed|zypper"

    # Arch-based (Pacman/AUR)
    "archlinux:latest|Arch Linux (Latest)|pacman"
)

#---------------------------------------------------------------------------------
# Parse arguments
#---------------------------------------------------------------------------------

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --parallel|-p)
                PARALLEL="$2"
                shift 2
                ;;
            --filter|-f)
                FILTER="$2"
                shift 2
                ;;
            --timeout|-t)
                TIMEOUT="$2"
                shift 2
                ;;
            --help|-h)
                echo "Usage: $0 [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  --parallel, -p N    Run N tests in parallel (default: 1)"
                echo "  --filter, -f TEXT   Only test distros matching TEXT"
                echo "  --timeout, -t SECS  Timeout per container in seconds (default: 300)"
                echo "  --help, -h          Show this help"
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                exit 1
                ;;
        esac
    done
}

#---------------------------------------------------------------------------------
# Pre-flight checks
#---------------------------------------------------------------------------------

preflight() {
    if ! command -v docker &>/dev/null; then
        echo -e "${RED}[ERROR]${NC} Docker is not installed or not in PATH."
        exit 1
    fi

    if ! docker info &>/dev/null 2>&1; then
        echo -e "${RED}[ERROR]${NC} Docker daemon is not running or current user lacks permissions."
        exit 1
    fi

    if [[ ! -f "$INSTALL_SCRIPT" ]]; then
        echo -e "${RED}[ERROR]${NC} Install script not found: ${INSTALL_SCRIPT}"
        exit 1
    fi

    mkdir -p "$LOG_DIR"
}

#---------------------------------------------------------------------------------
# Build the test command for each distro family
#
# Docker containers don't have systemd, so we validate installation by checking
# that the 'nordvpn' binary is present after running the install script.
# The install script already handles missing systemctl gracefully.
#---------------------------------------------------------------------------------

build_test_cmd() {
    local family="$1"

    case "$family" in
        apt)
            cat <<'DOCKER_CMD'
export DEBIAN_FRONTEND=noninteractive
bash /tmp/install-nordvpn.sh
RESULT=$?
if command -v nordvpn &>/dev/null; then
    echo "NORDVPN_BINARY_FOUND=true"
    nordvpn version 2>/dev/null || true
else
    echo "NORDVPN_BINARY_FOUND=false"
fi
exit $RESULT
DOCKER_CMD
            ;;
        dnf|yum)
            cat <<'DOCKER_CMD'
bash /tmp/install-nordvpn.sh
RESULT=$?
if command -v nordvpn &>/dev/null; then
    echo "NORDVPN_BINARY_FOUND=true"
    nordvpn version 2>/dev/null || true
else
    echo "NORDVPN_BINARY_FOUND=false"
fi
exit $RESULT
DOCKER_CMD
            ;;
        zypper)
            cat <<'DOCKER_CMD'
bash /tmp/install-nordvpn.sh
RESULT=$?
if command -v nordvpn &>/dev/null; then
    echo "NORDVPN_BINARY_FOUND=true"
    nordvpn version 2>/dev/null || true
else
    echo "NORDVPN_BINARY_FOUND=false"
fi
exit $RESULT
DOCKER_CMD
            ;;
        pacman)
            # Arch AUR requires a non-root user with sudo
            cat <<'DOCKER_CMD'
pacman -Syu --noconfirm sudo
useradd -m builder
echo "builder ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
export SUDO_USER=builder
bash /tmp/install-nordvpn.sh
RESULT=$?
if command -v nordvpn &>/dev/null || sudo -u builder command -v nordvpn &>/dev/null; then
    echo "NORDVPN_BINARY_FOUND=true"
    nordvpn version 2>/dev/null || true
else
    echo "NORDVPN_BINARY_FOUND=false"
fi
exit $RESULT
DOCKER_CMD
            ;;
    esac
}

#---------------------------------------------------------------------------------
# Run a single test
#---------------------------------------------------------------------------------

run_test() {
    local image="$1"
    local label="$2"
    local family="$3"
    local log_file="$4"

    local container_name="nordvpn-test-$(echo "$label" | tr ' ()/' '____' | tr '[:upper:]' '[:lower:]')"
    local test_cmd
    test_cmd=$(build_test_cmd "$family")

    echo -e "${CYAN}[START]${NC} ${label} (${image})" | tee -a "$log_file"

    # Remove any leftover container with the same name
    docker rm -f "$container_name" &>/dev/null 2>&1 || true

    # Pull image
    echo -e "${DIM}  Pulling ${image}...${NC}" | tee -a "$log_file"
    if ! docker pull "$image" >> "$log_file" 2>&1; then
        echo -e "${RED}[PULL FAIL]${NC} ${label} - Could not pull ${image}" | tee -a "$log_file"
        echo "PULL_FAIL"
        return
    fi

    # Run container with the install script mounted
    echo -e "${DIM}  Running install script...${NC}" | tee -a "$log_file"
    local output
    output=$(timeout "${TIMEOUT}s" docker run \
        --name "$container_name" \
        --rm \
        -v "${INSTALL_SCRIPT}:/tmp/install-nordvpn.sh:ro" \
        "$image" \
        bash -c "$test_cmd" 2>&1) || true

    echo "$output" >> "$log_file"

    # Check result
    if echo "$output" | grep -q "NORDVPN_BINARY_FOUND=true"; then
        echo -e "${GREEN}[PASS]${NC} ${label}" | tee -a "$log_file"
        echo "PASS"
    else
        echo -e "${RED}[FAIL]${NC} ${label}" | tee -a "$log_file"
        # Show last 5 lines of output for quick debugging
        echo -e "${DIM}  Last output lines:${NC}" | tee -a "$log_file"
        echo "$output" | tail -5 | sed 's/^/    /' | tee -a "$log_file"
        echo "FAIL"
    fi
}

#---------------------------------------------------------------------------------
# Main
#---------------------------------------------------------------------------------

main() {
    parse_args "$@"
    preflight

    local start_time
    start_time=$(date +%s)
    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)

    echo ""
    echo -e "${BOLD}=========================================${NC}"
    echo -e "${BOLD} NordVPN Installation Test Suite${NC}"
    echo -e "${BOLD}=========================================${NC}"
    echo ""
    echo -e "${CYAN}Install script:${NC} ${INSTALL_SCRIPT}"
    echo -e "${CYAN}Log directory:${NC}  ${LOG_DIR}"
    echo -e "${CYAN}Parallel:${NC}       ${PARALLEL}"
    echo -e "${CYAN}Timeout:${NC}        ${TIMEOUT}s per container"
    if [[ -n "$FILTER" ]]; then
        echo -e "${CYAN}Filter:${NC}         ${FILTER}"
    fi
    echo ""

    # Filter distros if requested
    local filtered_distros=()
    for entry in "${DISTROS[@]}"; do
        if [[ -z "$FILTER" ]] || echo "$entry" | grep -qi "$FILTER"; then
            filtered_distros+=("$entry")
        fi
    done

    local total=${#filtered_distros[@]}
    if [[ $total -eq 0 ]]; then
        echo -e "${YELLOW}[WARN]${NC} No distributions match filter '${FILTER}'."
        exit 0
    fi

    echo -e "${CYAN}Testing ${total} distribution(s)...${NC}"
    echo ""

    # Arrays to track results
    local -a passed=()
    local -a failed=()
    local -a pull_failed=()
    local current=0

    if [[ $PARALLEL -le 1 ]]; then
        # Sequential execution
        for entry in "${filtered_distros[@]}"; do
            IFS='|' read -r image label family <<< "$entry"
            current=$((current + 1))
            local log_file="${LOG_DIR}/${timestamp}_$(echo "$label" | tr ' ()/' '____').log"

            echo -e "${DIM}[${current}/${total}]${NC}"
            local result
            result=$(run_test "$image" "$label" "$family" "$log_file")

            case "$result" in
                PASS)      passed+=("$label") ;;
                PULL_FAIL) pull_failed+=("$label") ;;
                *)         failed+=("$label") ;;
            esac
            echo ""
        done
    else
        # Parallel execution
        local tmpdir
        tmpdir=$(mktemp -d)
        local job_count=0

        for entry in "${filtered_distros[@]}"; do
            IFS='|' read -r image label family <<< "$entry"
            current=$((current + 1))
            local log_file="${LOG_DIR}/${timestamp}_$(echo "$label" | tr ' ()/' '____').log"
            local result_file="${tmpdir}/$(echo "$label" | tr ' ()/' '____').result"

            (
                result=$(run_test "$image" "$label" "$family" "$log_file")
                echo "$result" > "$result_file"
            ) &

            job_count=$((job_count + 1))
            if [[ $job_count -ge $PARALLEL ]]; then
                wait -n 2>/dev/null || wait
                job_count=$((job_count - 1))
            fi
        done

        # Wait for remaining jobs
        wait

        # Collect results
        for entry in "${filtered_distros[@]}"; do
            IFS='|' read -r _ label _ <<< "$entry"
            local result_file="${tmpdir}/$(echo "$label" | tr ' ()/' '____').result"
            if [[ -f "$result_file" ]]; then
                local result
                result=$(cat "$result_file")
                case "$result" in
                    PASS)      passed+=("$label") ;;
                    PULL_FAIL) pull_failed+=("$label") ;;
                    *)         failed+=("$label") ;;
                esac
            else
                failed+=("$label")
            fi
        done

        rm -rf "$tmpdir"
    fi

    # Calculate duration
    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))
    local minutes=$((duration / 60))
    local seconds=$((duration % 60))

    # Print summary
    echo ""
    echo -e "${BOLD}=========================================${NC}"
    echo -e "${BOLD} Test Summary${NC}"
    echo -e "${BOLD}=========================================${NC}"
    echo ""
    echo -e "${CYAN}Total tested:${NC}  ${total}"
    echo -e "${GREEN}Passed:${NC}        ${#passed[@]}"
    echo -e "${RED}Failed:${NC}        ${#failed[@]}"
    if [[ ${#pull_failed[@]} -gt 0 ]]; then
        echo -e "${YELLOW}Pull failed:${NC}   ${#pull_failed[@]}"
    fi
    echo -e "${CYAN}Duration:${NC}      ${minutes}m ${seconds}s"
    echo ""

    if [[ ${#passed[@]} -gt 0 ]]; then
        echo -e "${GREEN}${BOLD}Passed distributions:${NC}"
        for dist in "${passed[@]}"; do
            echo -e "  ${GREEN}✓${NC} ${dist}"
        done
        echo ""
    fi

    if [[ ${#failed[@]} -gt 0 ]]; then
        echo -e "${RED}${BOLD}Failed distributions:${NC}"
        for dist in "${failed[@]}"; do
            echo -e "  ${RED}✗${NC} ${dist}"
        done
        echo ""
    fi

    if [[ ${#pull_failed[@]} -gt 0 ]]; then
        echo -e "${YELLOW}${BOLD}Pull failed (image not available):${NC}"
        for dist in "${pull_failed[@]}"; do
            echo -e "  ${YELLOW}⚠${NC} ${dist}"
        done
        echo ""
    fi

    echo -e "${DIM}Logs saved to: ${LOG_DIR}/${NC}"
    echo ""

    # Exit with error code if any test failed
    if [[ ${#failed[@]} -gt 0 || ${#pull_failed[@]} -gt 0 ]]; then
        exit 1
    fi

    exit 0
}

main "$@"
