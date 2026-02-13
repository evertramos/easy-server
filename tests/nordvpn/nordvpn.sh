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
# Spinner - shows animated progress on the current line
#---------------------------------------------------------------------------------

SPINNER_PID=""

spinner_start() {
    local label="$1"
    local phase="$2"
    local frames=('/' '-' '\' '|')

    (
        local i=0
        local start_ts
        start_ts=$(date +%s)
        while true; do
            local elapsed=$(( $(date +%s) - start_ts ))
            local mins=$((elapsed / 60))
            local secs=$((elapsed % 60))
            local time_str
            if [[ $mins -gt 0 ]]; then
                time_str="${mins}m${secs}s"
            else
                time_str="${secs}s"
            fi
            local frame="${frames[$((i % 4))]}"
            printf "\r  ${DIM}%s${NC} ${phase}  ${DIM}%s${NC}   " "$frame" "$time_str" >&2
            i=$((i + 1))
            sleep 0.25
        done
    ) &
    SPINNER_PID=$!
    disown "$SPINNER_PID" 2>/dev/null
}

spinner_stop() {
    if [[ -n "${SPINNER_PID:-}" ]]; then
        kill "$SPINNER_PID" 2>/dev/null
        wait "$SPINNER_PID" 2>/dev/null || true
        printf "\r\033[K" >&2
        SPINNER_PID=""
    fi
}

# Ensure spinner is cleaned up on exit
trap 'spinner_stop' EXIT

#---------------------------------------------------------------------------------
# Format elapsed time
#---------------------------------------------------------------------------------

format_time() {
    local secs="$1"
    local mins=$((secs / 60))
    local rem=$((secs % 60))
    if [[ $mins -gt 0 ]]; then
        echo "${mins}m${rem}s"
    else
        echo "${rem}s"
    fi
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
# Progress bar
#---------------------------------------------------------------------------------

print_progress_bar() {
    local current="$1"
    local total="$2"
    local passed="$3"
    local failed="$4"
    local width=30
    local filled=$((current * width / total))
    local empty=$((width - filled))

    local bar=""
    for ((i = 0; i < filled; i++)); do bar+="="; done
    if [[ $filled -lt $width ]]; then
        bar+=">"
        for ((i = 1; i < empty; i++)); do bar+=" "; done
    fi

    printf "\r  ${DIM}[${NC}${CYAN}%s${NC}${DIM}]${NC} %d/%d  " "$bar" "$current" "$total" >&2
    printf "${GREEN}%d passed${NC}  ${RED}%d failed${NC}   \n" "$passed" "$failed" >&2
}

#---------------------------------------------------------------------------------
# Run a single test (writes result to result_file, progress to terminal)
#---------------------------------------------------------------------------------

run_test() {
    local image="$1"
    local label="$2"
    local family="$3"
    local log_file="$4"
    local result_file="$5"
    local counter="$6"

    local container_name="nordvpn-test-$(echo "$label" | tr ' ()/' '____' | tr '[:upper:]' '[:lower:]')"
    local test_cmd
    test_cmd=$(build_test_cmd "$family")
    local test_start
    test_start=$(date +%s)

    printf "\n  ${BOLD}[%s]${NC} ${CYAN}%s${NC} ${DIM}(%s)${NC}\n" "$counter" "$label" "$image" >&2
    echo "[START] ${label} (${image})" >> "$log_file"

    # Remove any leftover container with the same name
    docker rm -f "$container_name" &>/dev/null 2>&1 || true

    # --- Pull image ---
    spinner_start "$label" "Pulling image..."
    if ! docker pull "$image" >> "$log_file" 2>&1; then
        spinner_stop
        local elapsed=$(( $(date +%s) - test_start ))
        printf "  ${RED}PULL FAIL${NC}  Could not pull ${image}  ${DIM}%s${NC}\n" "$(format_time $elapsed)" >&2
        echo "[PULL FAIL] ${label}" >> "$log_file"
        echo "PULL_FAIL" > "$result_file"
        return
    fi
    spinner_stop

    # --- Run install script ---
    spinner_start "$label" "Installing NordVPN..."
    local output
    output=$(timeout "${TIMEOUT}s" docker run \
        --name "$container_name" \
        --rm \
        -v "${INSTALL_SCRIPT}:/tmp/install-nordvpn.sh:ro" \
        "$image" \
        bash -c "$test_cmd" 2>&1) || true
    spinner_stop

    echo "$output" >> "$log_file"

    local elapsed=$(( $(date +%s) - test_start ))

    # --- Check result ---
    if echo "$output" | grep -q "NORDVPN_BINARY_FOUND=true"; then
        printf "  ${GREEN}PASS${NC}  %s  ${DIM}%s${NC}\n" "$label" "$(format_time $elapsed)" >&2
        echo "[PASS] ${label}" >> "$log_file"
        echo "PASS" > "$result_file"
    else
        printf "  ${RED}FAIL${NC}  %s  ${DIM}%s${NC}\n" "$label" "$(format_time $elapsed)" >&2
        echo "$output" | tail -3 | sed 's/^/         /' >&2
        echo "[FAIL] ${label}" >> "$log_file"
        echo "FAIL" > "$result_file"
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
    echo -e "  ${CYAN}Script:${NC}   ${INSTALL_SCRIPT}"
    echo -e "  ${CYAN}Logs:${NC}     ${LOG_DIR}"
    echo -e "  ${CYAN}Parallel:${NC} ${PARALLEL}"
    echo -e "  ${CYAN}Timeout:${NC}  ${TIMEOUT}s per container"
    if [[ -n "$FILTER" ]]; then
        echo -e "  ${CYAN}Filter:${NC}   ${FILTER}"
    fi

    # Filter distros if requested
    local filtered_distros=()
    for entry in "${DISTROS[@]}"; do
        if [[ -z "$FILTER" ]] || echo "$entry" | grep -qi "$FILTER"; then
            filtered_distros+=("$entry")
        fi
    done

    local total=${#filtered_distros[@]}
    if [[ $total -eq 0 ]]; then
        echo -e "\n  ${YELLOW}No distributions match filter '${FILTER}'.${NC}"
        exit 0
    fi

    echo ""
    echo -e "  ${BOLD}Testing ${total} distribution(s)${NC}"
    echo -e "  ${DIM}$(printf '%.0s-' {1..45})${NC}"

    # Prepare result files
    local tmpdir
    tmpdir=$(mktemp -d)

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
            local result_file="${tmpdir}/$(echo "$label" | tr ' ()/' '____').result"

            run_test "$image" "$label" "$family" "$log_file" "$result_file" "${current}/${total}"

            local result
            result=$(cat "$result_file" 2>/dev/null || echo "FAIL")
            case "$result" in
                PASS)      passed+=("$label") ;;
                PULL_FAIL) pull_failed+=("$label") ;;
                *)         failed+=("$label") ;;
            esac

            # Show running tally
            print_progress_bar "$current" "$total" "${#passed[@]}" "$(( ${#failed[@]} + ${#pull_failed[@]} ))"
        done
    else
        # Parallel execution
        local job_count=0

        for entry in "${filtered_distros[@]}"; do
            IFS='|' read -r image label family <<< "$entry"
            current=$((current + 1))
            local log_file="${LOG_DIR}/${timestamp}_$(echo "$label" | tr ' ()/' '____').log"
            local result_file="${tmpdir}/$(echo "$label" | tr ' ()/' '____').result"

            (
                run_test "$image" "$label" "$family" "$log_file" "$result_file" "${current}/${total}"
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
    fi

    rm -rf "$tmpdir"

    # Calculate duration
    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))

    # Print summary
    echo ""
    echo -e "  ${DIM}$(printf '%.0s-' {1..45})${NC}"
    echo -e "  ${BOLD}Results${NC}                  ${DIM}$(format_time $duration) total${NC}"
    echo -e "  ${DIM}$(printf '%.0s-' {1..45})${NC}"
    echo ""

    # Results table
    local pass_count=${#passed[@]}
    local fail_count=${#failed[@]}
    local pull_count=${#pull_failed[@]}
    local pass_pct=0
    if [[ $total -gt 0 ]]; then
        pass_pct=$((pass_count * 100 / total))
    fi

    echo -e "  ${CYAN}Total:${NC}    ${total} distributions"
    echo -e "  ${GREEN}Passed:${NC}   ${pass_count}  ${DIM}(${pass_pct}%)${NC}"
    echo -e "  ${RED}Failed:${NC}   ${fail_count}"
    if [[ $pull_count -gt 0 ]]; then
        echo -e "  ${YELLOW}Skipped:${NC}  ${pull_count}  ${DIM}(image pull failed)${NC}"
    fi
    echo ""

    if [[ ${#passed[@]} -gt 0 ]]; then
        echo -e "  ${GREEN}${BOLD}Passed:${NC}"
        for dist in "${passed[@]}"; do
            echo -e "    ${GREEN}*${NC} ${dist}"
        done
        echo ""
    fi

    if [[ ${#failed[@]} -gt 0 ]]; then
        echo -e "  ${RED}${BOLD}Failed:${NC}"
        for dist in "${failed[@]}"; do
            echo -e "    ${RED}*${NC} ${dist}"
        done
        echo ""
    fi

    if [[ ${#pull_failed[@]} -gt 0 ]]; then
        echo -e "  ${YELLOW}${BOLD}Skipped (pull failed):${NC}"
        for dist in "${pull_failed[@]}"; do
            echo -e "    ${YELLOW}*${NC} ${dist}"
        done
        echo ""
    fi

    echo -e "  ${DIM}Logs: ${LOG_DIR}/${NC}"
    echo ""

    # Exit with error code if any test failed
    if [[ $fail_count -gt 0 || $pull_count -gt 0 ]]; then
        exit 1
    fi

    exit 0
}

main "$@"
