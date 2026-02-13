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
VERBOSE=false

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

    # RPM-based (DNF - RHEL 9 family)
    "rockylinux:9|Rocky Linux 9|dnf"
    "almalinux:9|AlmaLinux 9|dnf"

    # RPM-based (YUM - RHEL 8 family, glibc 2.28 - NordVPN needs >= 2.29, expect FAIL)
    "rockylinux:8|Rocky Linux 8|yum"
    "almalinux:8|AlmaLinux 8|yum"

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
            --verbose|-v)
                VERBOSE=true
                shift
                ;;
            --help|-h)
                echo "Usage: $0 [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  --parallel, -p N    Run N tests in parallel (default: 1)"
                echo "  --filter, -f TEXT   Only test distros matching TEXT"
                echo "  --timeout, -t SECS  Timeout per container in seconds (default: 300)"
                echo "  --verbose, -v       Show full error output for failed tests"
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
# Spinner - shows animated progress on the current line (sequential mode only)
#---------------------------------------------------------------------------------

SPINNER_PID=""

spinner_start() {
    local phase="$1"
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
            printf "\r  ${DIM}%s${NC} %s  ${DIM}%s${NC}   " "$frame" "$phase" "$time_str" >&2
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

#---------------------------------------------------------------------------------
# Format elapsed time
#---------------------------------------------------------------------------------

format_time() {
    local secs="$1"
    local mins=$((secs / 60))
    local rem=$((secs % 60))
    if [[ $mins -gt 0 ]]; then
        printf "%dm%ds" "$mins" "$rem"
    else
        printf "%ds" "$rem"
    fi
}

#---------------------------------------------------------------------------------
# Build the test command for each distro family
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
# Progress bar (used in both modes)
#---------------------------------------------------------------------------------

render_progress_bar() {
    local current="$1"
    local total="$2"
    local passed="$3"
    local failed="$4"
    local width=30
    local filled=0
    if [[ $total -gt 0 && $current -gt 0 ]]; then
        filled=$((current * width / total))
    fi

    local bar=""
    for ((i = 0; i < filled; i++)); do bar+="="; done
    if [[ $filled -lt $width ]]; then
        bar+=">"
        for ((i = filled + 1; i < width; i++)); do bar+=" "; done
    fi

    printf "  ${DIM}[${NC}${CYAN}%s${NC}${DIM}]${NC} %d/%d  ${GREEN}%d passed${NC}  ${RED}%d failed${NC}" \
        "$bar" "$current" "$total" "$passed" "$failed"
}

#=================================================================================
#  SEQUENTIAL MODE
#=================================================================================

run_test_sequential() {
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

    docker rm -f "$container_name" &>/dev/null 2>&1 || true

    # Pull
    spinner_start "Pulling image..."
    if ! docker pull "$image" >> "$log_file" 2>&1; then
        spinner_stop
        local elapsed=$(( $(date +%s) - test_start ))
        printf "  ${RED}PULL FAIL${NC}  Could not pull ${image}  ${DIM}%s${NC}\n" "$(format_time $elapsed)" >&2
        echo "PULL_FAIL" > "$result_file"
        return
    fi
    spinner_stop

    # Install
    spinner_start "Installing NordVPN..."
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

    local error_file="${result_file%.result}.error"
    local logref_file="${result_file%.result}.log_path"
    echo "$log_file" > "$logref_file"

    if echo "$output" | grep -q "NORDVPN_BINARY_FOUND=true"; then
        printf "  ${GREEN}PASS${NC}  %s  ${DIM}%s${NC}\n" "$label" "$(format_time $elapsed)" >&2
        echo "PASS" > "$result_file"
    else
        printf "  ${RED}FAIL${NC}  %s  ${DIM}%s${NC}\n" "$label" "$(format_time $elapsed)" >&2
        echo "$output" | tail -3 | sed 's/^/         /' >&2
        echo "FAIL" > "$result_file"
        # Save error snippet for the summary
        echo "$output" | grep -iE '(error|fail|nothing|cannot|unable|denied|not found|unbound)' \
            | tail -5 > "$error_file" 2>/dev/null || true
        # Fallback: last non-empty lines if no pattern matched
        if [[ ! -s "$error_file" ]]; then
            echo "$output" | grep -v '^\s*$' | tail -5 > "$error_file" 2>/dev/null || true
        fi
    fi
}

#=================================================================================
#  PARALLEL MODE - Live dashboard
#=================================================================================

# Globals for the dashboard
STATUS_DIR=""
DASHBOARD_LABELS=()
DASHBOARD_TOTAL=0
RENDERER_PID=""
DASHBOARD_LINES=0

# Write a status update for a distro (called from test subshells)
# Phases: waiting, pulling, installing, pass, fail, pull_fail
# Format: "phase|timestamp_or_elapsed"
#   Active phases use start timestamp (renderer computes elapsed)
#   Final phases use total elapsed seconds (fixed display)
write_status() {
    local label="$1"
    local phase="$2"
    local value="$3"
    local sanitized
    sanitized=$(echo "$label" | tr ' ()/' '____')
    echo "${phase}|${value}" > "${STATUS_DIR}/${sanitized}.status"
}

# Render the full dashboard (all distros + progress bar)
render_dashboard() {
    local now
    now=$(date +%s)
    local frames=('/' '-' '\' '|')
    local frame_idx=$(( now % 4 ))
    local frame="${frames[$frame_idx]}"

    local pass_count=0
    local fail_count=0
    local done_count=0

    # Move cursor up to overwrite previous render
    if [[ $DASHBOARD_LINES -gt 0 ]]; then
        printf "\033[%dA" "$DASHBOARD_LINES" >&2
    fi

    local lines_printed=0

    for i in "${!DASHBOARD_LABELS[@]}"; do
        local label="${DASHBOARD_LABELS[$i]}"
        local num=$((i + 1))
        local sanitized
        sanitized=$(echo "$label" | tr ' ()/' '____')
        local status_file="${STATUS_DIR}/${sanitized}.status"

        local phase="waiting"
        local value="0"
        if [[ -f "$status_file" ]]; then
            IFS='|' read -r phase value < "$status_file" 2>/dev/null || true
        fi

        local padded_num
        padded_num=$(printf "%2d" "$num")
        local padded_label
        padded_label=$(printf "%-28s" "$label")

        case "$phase" in
            waiting)
                printf "\033[K  ${DIM}%s. %s         Waiting${NC}\n" \
                    "$padded_num" "$padded_label" >&2
                ;;
            pulling)
                local elapsed=$(( now - value ))
                printf "\033[K  ${DIM}%s.${NC} %s  ${CYAN}%s${NC}  Pulling      ${DIM}%s${NC}\n" \
                    "$padded_num" "$padded_label" "$frame" "$(format_time $elapsed)" >&2
                ;;
            installing)
                local elapsed=$(( now - value ))
                printf "\033[K  ${DIM}%s.${NC} %s  ${CYAN}%s${NC}  Installing   ${DIM}%s${NC}\n" \
                    "$padded_num" "$padded_label" "$frame" "$(format_time $elapsed)" >&2
                ;;
            pass)
                printf "\033[K  ${DIM}%s.${NC} %s  ${GREEN}PASS${NC}             ${DIM}%s${NC}\n" \
                    "$padded_num" "$padded_label" "$(format_time "$value")" >&2
                ((pass_count++))
                ((done_count++))
                ;;
            fail)
                printf "\033[K  ${DIM}%s.${NC} %s  ${RED}FAIL${NC}             ${DIM}%s${NC}\n" \
                    "$padded_num" "$padded_label" "$(format_time "$value")" >&2
                ((fail_count++))
                ((done_count++))
                ;;
            pull_fail)
                printf "\033[K  ${DIM}%s.${NC} %s  ${YELLOW}PULL FAIL${NC}        ${DIM}%s${NC}\n" \
                    "$padded_num" "$padded_label" "$(format_time "$value")" >&2
                ((fail_count++))
                ((done_count++))
                ;;
        esac
        ((lines_printed++))
    done

    # Empty line + progress bar
    printf "\033[K\n" >&2
    printf "\033[K%s\n" "$(render_progress_bar "$done_count" "$DASHBOARD_TOTAL" "$pass_count" "$fail_count")" >&2
    lines_printed=$((lines_printed + 2))

    DASHBOARD_LINES=$lines_printed
}

# Background renderer loop
start_renderer() {
    (
        while true; do
            render_dashboard
            sleep 0.4
        done
    ) &
    RENDERER_PID=$!
    disown "$RENDERER_PID" 2>/dev/null
}

stop_renderer() {
    if [[ -n "${RENDERER_PID:-}" ]]; then
        kill "$RENDERER_PID" 2>/dev/null
        wait "$RENDERER_PID" 2>/dev/null || true
        RENDERER_PID=""
    fi
}

# Run a single test in parallel mode (writes status updates, no terminal output)
run_test_parallel() {
    local image="$1"
    local label="$2"
    local family="$3"
    local log_file="$4"
    local result_file="$5"

    local container_name="nordvpn-test-$(echo "$label" | tr ' ()/' '____' | tr '[:upper:]' '[:lower:]')"
    local test_cmd
    test_cmd=$(build_test_cmd "$family")
    local test_start
    test_start=$(date +%s)

    local error_file="${result_file%.result}.error"
    local logref_file="${result_file%.result}.log_path"
    echo "$log_file" > "$logref_file"

    echo "[START] ${label} (${image})" >> "$log_file"
    docker rm -f "$container_name" &>/dev/null 2>&1 || true

    # Pull
    write_status "$label" "pulling" "$test_start"
    if ! docker pull "$image" >> "$log_file" 2>&1; then
        local elapsed=$(( $(date +%s) - test_start ))
        write_status "$label" "pull_fail" "$elapsed"
        echo "PULL_FAIL" > "$result_file"
        echo "Could not pull image: ${image}" > "$error_file"
        return
    fi

    # Install
    write_status "$label" "installing" "$test_start"
    local output
    output=$(timeout "${TIMEOUT}s" docker run \
        --name "$container_name" \
        --rm \
        -v "${INSTALL_SCRIPT}:/tmp/install-nordvpn.sh:ro" \
        "$image" \
        bash -c "$test_cmd" 2>&1) || true

    echo "$output" >> "$log_file"
    local elapsed=$(( $(date +%s) - test_start ))

    if echo "$output" | grep -q "NORDVPN_BINARY_FOUND=true"; then
        write_status "$label" "pass" "$elapsed"
        echo "PASS" > "$result_file"
    else
        write_status "$label" "fail" "$elapsed"
        echo "FAIL" > "$result_file"
        # Save error snippet for the summary
        echo "$output" | grep -iE '(error|fail|nothing|cannot|unable|denied|not found|unbound)' \
            | tail -5 > "$error_file" 2>/dev/null || true
        if [[ ! -s "$error_file" ]]; then
            echo "$output" | grep -v '^\s*$' | tail -5 > "$error_file" 2>/dev/null || true
        fi
    fi
}

#=================================================================================
#  MAIN
#=================================================================================

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

    # Filter distros
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
    echo -e "  ${DIM}$(printf '%.0s-' {1..50})${NC}"

    local tmpdir
    tmpdir=$(mktemp -d)

    # Cleanup on exit
    trap 'spinner_stop; stop_renderer; rm -rf "$tmpdir"' EXIT

    local -a passed=()
    local -a failed=()
    local -a pull_failed=()

    if [[ $PARALLEL -le 1 ]]; then
        #---------------------------------------------------------------------
        # Sequential mode (with spinner)
        #---------------------------------------------------------------------
        local current=0
        for entry in "${filtered_distros[@]}"; do
            IFS='|' read -r image label family <<< "$entry"
            current=$((current + 1))
            local log_file="${LOG_DIR}/${timestamp}_$(echo "$label" | tr ' ()/' '____').log"
            local result_file="${tmpdir}/$(echo "$label" | tr ' ()/' '____').result"

            run_test_sequential "$image" "$label" "$family" "$log_file" "$result_file" "${current}/${total}"

            local result
            result=$(cat "$result_file" 2>/dev/null || echo "FAIL")
            case "$result" in
                PASS)      passed+=("$label") ;;
                PULL_FAIL) pull_failed+=("$label") ;;
                *)         failed+=("$label") ;;
            esac

            printf "\n%s\n" "$(render_progress_bar "$current" "$total" "${#passed[@]}" "$(( ${#failed[@]} + ${#pull_failed[@]} ))")" >&2
        done
    else
        #---------------------------------------------------------------------
        # Parallel mode (with live dashboard)
        #---------------------------------------------------------------------
        STATUS_DIR="${tmpdir}/status"
        mkdir -p "$STATUS_DIR"
        DASHBOARD_TOTAL=$total
        DASHBOARD_LABELS=()
        DASHBOARD_LINES=0

        # Initialize all status files and label array
        for entry in "${filtered_distros[@]}"; do
            IFS='|' read -r _ label _ <<< "$entry"
            DASHBOARD_LABELS+=("$label")
            write_status "$label" "waiting" "0"
        done

        # Initial render + start background renderer
        echo "" >&2
        render_dashboard
        start_renderer

        # Concurrency control via FIFO semaphore
        local fifo="${tmpdir}/fifo"
        mkfifo "$fifo"
        exec 3<>"$fifo"
        for ((i = 0; i < PARALLEL; i++)); do
            echo >&3
        done

        local all_pids=()

        for entry in "${filtered_distros[@]}"; do
            IFS='|' read -r image label family <<< "$entry"
            local log_file="${LOG_DIR}/${timestamp}_$(echo "$label" | tr ' ()/' '____').log"
            local result_file="${tmpdir}/$(echo "$label" | tr ' ()/' '____').result"

            # Wait for an available slot
            read -u 3

            (
                run_test_parallel "$image" "$label" "$family" "$log_file" "$result_file"
                echo >&3  # Release slot
            ) &
            all_pids+=($!)
        done

        # Wait for all test jobs to finish
        for pid in "${all_pids[@]}"; do
            wait "$pid" 2>/dev/null || true
        done

        exec 3>&-

        # Stop renderer and do one final render
        stop_renderer
        render_dashboard

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

    # Duration
    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))

    # Summary
    local pass_count=${#passed[@]}
    local fail_count=${#failed[@]}
    local pull_count=${#pull_failed[@]}
    local error_total=$((fail_count + pull_count))
    local pass_pct=0
    if [[ $total -gt 0 ]]; then
        pass_pct=$((pass_count * 100 / total))
    fi

    echo ""
    echo -e "  ${DIM}$(printf '%.0s-' {1..50})${NC}"
    echo -e "  ${BOLD}Results${NC}                       ${DIM}$(format_time $duration) total${NC}"
    echo -e "  ${DIM}$(printf '%.0s-' {1..50})${NC}"
    echo ""
    echo -e "  ${CYAN}Total:${NC}    ${total} distributions"
    echo -e "  ${GREEN}Passed:${NC}   ${pass_count}  ${DIM}(${pass_pct}%)${NC}"
    echo -e "  ${RED}Failed:${NC}   ${error_total}"
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
            local sanitized
            sanitized=$(echo "$dist" | tr ' ()/' '____')
            local error_file="${tmpdir}/${sanitized}.error"
            local logref_file="${tmpdir}/${sanitized}.log_path"
            local log_path=""
            if [[ -f "$logref_file" ]]; then
                log_path=$(cat "$logref_file")
            fi

            echo -e "    ${RED}*${NC} ${dist}"

            if [[ "$VERBOSE" == true && -n "$log_path" && -f "$log_path" ]]; then
                # Verbose: show last 20 lines of the full log
                echo -e "      ${DIM}--- last 20 lines of log ---${NC}"
                tail -20 "$log_path" | while IFS= read -r line; do
                    echo -e "      ${DIM}${line}${NC}"
                done
                echo -e "      ${DIM}----------------------------${NC}"
            elif [[ -f "$error_file" && -s "$error_file" ]]; then
                # Normal: show filtered error snippet
                while IFS= read -r line; do
                    echo -e "      ${DIM}${line}${NC}"
                done < "$error_file"
            fi

            if [[ -n "$log_path" ]]; then
                echo -e "      ${DIM}Log: ${log_path}${NC}"
            fi
            echo ""
        done
    fi

    if [[ ${#pull_failed[@]} -gt 0 ]]; then
        echo -e "  ${YELLOW}${BOLD}Skipped (pull failed):${NC}"
        for dist in "${pull_failed[@]}"; do
            local sanitized
            sanitized=$(echo "$dist" | tr ' ()/' '____')
            local logref_file="${tmpdir}/${sanitized}.log_path"
            local log_path=""
            if [[ -f "$logref_file" ]]; then
                log_path=$(cat "$logref_file")
            fi

            echo -e "    ${YELLOW}*${NC} ${dist}"
            echo -e "      ${DIM}Could not pull Docker image${NC}"
            if [[ -n "$log_path" ]]; then
                echo -e "      ${DIM}Log: ${log_path}${NC}"
            fi
            echo ""
        done
    fi

    echo -e "  ${DIM}All logs: ${LOG_DIR}/${NC}"
    echo ""

    if [[ $error_total -gt 0 ]]; then
        exit 1
    fi
    exit 0
}

main "$@"
