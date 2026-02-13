#!/bin/bash

#---------------------------------------------------------------------------------
# NordVPN Client Installation Script
# Supports: Debian, Ubuntu, Linux Mint, Raspberry Pi OS, Fedora, CentOS, RHEL,
#           openSUSE, Kali Linux, Arch Linux, BlackArch, Manjaro
#
# Official docs: https://support.nordvpn.com/hc/en-us/articles/20196094470929
#---------------------------------------------------------------------------------

set -euo pipefail

NORDVPN_GPG_URL="https://repo.nordvpn.com/gpg/nordvpn_public.asc"
NORDVPN_DEB_REPO="https://repo.nordvpn.com/deb/nordvpn/debian"
NORDVPN_RPM_REPO="https://repo.nordvpn.com/yum/nordvpn/centos/x86_64"
NORDVPN_INSTALL_SCRIPT="https://downloads.nordcdn.com/apps/linux/install.sh"
PACKAGE_NAME="nordvpn"

#---------------------------------------------------------------------------------
# Colors and output helpers
#---------------------------------------------------------------------------------

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

log_info()    { echo -e "${CYAN}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; }

#---------------------------------------------------------------------------------
# Root check
#---------------------------------------------------------------------------------

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root or with sudo."
        exit 1
    fi
}

#---------------------------------------------------------------------------------
# Detect distribution
#---------------------------------------------------------------------------------

detect_distro() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        DISTRO_ID="${ID,,}"
        DISTRO_ID_LIKE="${ID_LIKE,,:-}"
        DISTRO_NAME="${NAME}"
        DISTRO_VERSION="${VERSION_ID:-unknown}"
    elif [[ -f /etc/redhat-release ]]; then
        DISTRO_ID="rhel"
        DISTRO_ID_LIKE="rhel"
        DISTRO_NAME=$(cat /etc/redhat-release)
        DISTRO_VERSION="unknown"
    else
        log_error "Cannot detect Linux distribution. /etc/os-release not found."
        exit 1
    fi

    log_info "Detected: ${DISTRO_NAME} (${DISTRO_ID} ${DISTRO_VERSION})"
}

#---------------------------------------------------------------------------------
# Determine package manager family
#---------------------------------------------------------------------------------

get_pkg_family() {
    case "$DISTRO_ID" in
        ubuntu|debian|linuxmint|raspbian|kali|pop|elementary|zorin|mx)
            PKG_FAMILY="apt"
            ;;
        fedora|qubes)
            PKG_FAMILY="dnf"
            ;;
        centos|rhel|rocky|almalinux|ol|amzn)
            PKG_FAMILY="yum"
            ;;
        opensuse*|sles)
            PKG_FAMILY="zypper"
            ;;
        arch|manjaro|blackarch|endeavouros|garuda|artix)
            PKG_FAMILY="pacman"
            ;;
        *)
            # Fallback: check ID_LIKE for derivative distros
            if echo "$DISTRO_ID_LIKE" | grep -qw "debian\|ubuntu"; then
                PKG_FAMILY="apt"
            elif echo "$DISTRO_ID_LIKE" | grep -qw "rhel\|centos\|fedora"; then
                if command -v dnf &>/dev/null; then
                    PKG_FAMILY="dnf"
                else
                    PKG_FAMILY="yum"
                fi
            elif echo "$DISTRO_ID_LIKE" | grep -qw "suse"; then
                PKG_FAMILY="zypper"
            elif echo "$DISTRO_ID_LIKE" | grep -qw "arch"; then
                PKG_FAMILY="pacman"
            else
                log_error "Unsupported distribution: ${DISTRO_NAME} (${DISTRO_ID})"
                log_info "You can try the official install script manually:"
                log_info "  sh <(curl -sSf ${NORDVPN_INSTALL_SCRIPT})"
                exit 1
            fi
            ;;
    esac

    log_info "Package manager family: ${PKG_FAMILY}"
}

#---------------------------------------------------------------------------------
# Check dependencies
#---------------------------------------------------------------------------------

check_dependencies() {
    local deps=("curl" "ca-certificates")

    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &>/dev/null; then
            log_info "Installing missing dependency: ${dep}"
            case "$PKG_FAMILY" in
                apt)    apt-get install -y "$dep" ;;
                dnf)    dnf install -y "$dep" ;;
                yum)    yum install -y "$dep" ;;
                zypper) zypper install -y "$dep" ;;
                pacman) pacman -S --noconfirm "$dep" ;;
            esac
        fi
    done
}

#---------------------------------------------------------------------------------
# Check if NordVPN is already installed
#---------------------------------------------------------------------------------

check_existing() {
    if command -v nordvpn &>/dev/null; then
        local current_version
        current_version=$(nordvpn version 2>/dev/null || echo "unknown")
        log_warn "NordVPN is already installed (${current_version})."
        read -rp "Do you want to reinstall/upgrade? [y/N]: " confirm
        if [[ "${confirm,,}" != "y" ]]; then
            log_info "Installation cancelled."
            exit 0
        fi
    fi
}

#---------------------------------------------------------------------------------
# Install via APT (Debian, Ubuntu, Mint, Kali, Raspberry Pi OS, etc.)
#---------------------------------------------------------------------------------

install_apt() {
    log_info "Setting up NordVPN APT repository..."

    # Install prerequisites
    apt-get update
    apt-get install -y curl ca-certificates gnupg

    # Create keyrings directory
    install -m 0755 -d /usr/share/keyrings

    # Import GPG key
    curl -fsSL "$NORDVPN_GPG_URL" \
        | gpg --dearmor \
        | tee /usr/share/keyrings/nordvpn-archive-keyring.gpg >/dev/null

    # Add repository
    echo "deb [signed-by=/usr/share/keyrings/nordvpn-archive-keyring.gpg] ${NORDVPN_DEB_REPO} stable main" \
        | tee /etc/apt/sources.list.d/nordvpn.list >/dev/null

    # Install NordVPN
    apt-get update
    apt-get install -y "$PACKAGE_NAME"

    log_success "NordVPN installed via APT."
}

#---------------------------------------------------------------------------------
# Install via DNF (Fedora, Qubes)
#---------------------------------------------------------------------------------

install_dnf() {
    log_info "Setting up NordVPN DNF repository..."

    # Import GPG key
    rpm -v --import "$NORDVPN_GPG_URL"

    # Add repository
    cat > /etc/yum.repos.d/nordvpn.repo <<EOF
[nordvpn]
name=NordVPN
baseurl=${NORDVPN_RPM_REPO}
enabled=1
gpgcheck=1
gpgkey=${NORDVPN_GPG_URL}
EOF

    # Install NordVPN
    dnf install -y "$PACKAGE_NAME"

    log_success "NordVPN installed via DNF."
}

#---------------------------------------------------------------------------------
# Install via YUM (CentOS, RHEL, Rocky, AlmaLinux)
#---------------------------------------------------------------------------------

install_yum() {
    log_info "Setting up NordVPN YUM repository..."

    # Import GPG key
    rpm -v --import "$NORDVPN_GPG_URL"

    # Add repository
    cat > /etc/yum.repos.d/nordvpn.repo <<EOF
[nordvpn]
name=NordVPN
baseurl=${NORDVPN_RPM_REPO}
enabled=1
gpgcheck=1
gpgkey=${NORDVPN_GPG_URL}
EOF

    # Install NordVPN
    yum install -y "$PACKAGE_NAME"

    log_success "NordVPN installed via YUM."
}

#---------------------------------------------------------------------------------
# Install via Zypper (openSUSE, SLES)
#---------------------------------------------------------------------------------

install_zypper() {
    log_info "Setting up NordVPN Zypper repository..."

    # Import GPG key
    rpm -v --import "$NORDVPN_GPG_URL"

    # Add repository
    zypper addrepo --refresh --gpgcheck "$NORDVPN_RPM_REPO" nordvpn

    # Install NordVPN
    zypper install -y "$PACKAGE_NAME"

    log_success "NordVPN installed via Zypper."
}

#---------------------------------------------------------------------------------
# Install via Pacman/AUR (Arch, Manjaro, BlackArch, EndeavourOS)
#---------------------------------------------------------------------------------

install_pacman() {
    log_warn "NordVPN is not officially supported on Arch-based distributions."
    log_info "Installing from AUR (community package: nordvpn-bin)..."

    # Determine which AUR helper is available
    local aur_helper=""
    if command -v yay &>/dev/null; then
        aur_helper="yay"
    elif command -v paru &>/dev/null; then
        aur_helper="paru"
    fi

    if [[ -n "$aur_helper" ]]; then
        log_info "Using AUR helper: ${aur_helper}"
        # AUR helpers must NOT run as root
        if [[ -n "${SUDO_USER:-}" ]]; then
            su - "$SUDO_USER" -c "${aur_helper} -S --noconfirm nordvpn-bin"
        else
            log_error "AUR helpers must not run as root. Run this script with sudo instead of as root."
            exit 1
        fi
    else
        log_info "No AUR helper found. Installing nordvpn-bin manually from AUR..."

        # Install build dependencies
        pacman -S --needed --noconfirm base-devel git

        local build_dir="/tmp/nordvpn-aur-build"
        rm -rf "$build_dir"

        if [[ -n "${SUDO_USER:-}" ]]; then
            su - "$SUDO_USER" -c "
                git clone https://aur.archlinux.org/nordvpn-bin.git '${build_dir}' && \
                cd '${build_dir}' && \
                makepkg -si --noconfirm
            "
        else
            log_error "Cannot build AUR packages as root. Run this script with sudo instead."
            exit 1
        fi

        rm -rf "$build_dir"
    fi

    log_success "NordVPN installed via AUR (nordvpn-bin)."
}

#---------------------------------------------------------------------------------
# Post-installation setup
#---------------------------------------------------------------------------------

post_install() {
    log_info "Running post-installation setup..."

    # Enable and start the NordVPN daemon
    if command -v systemctl &>/dev/null; then
        systemctl enable --now nordvpnd
        log_success "NordVPN daemon enabled and started."
    else
        log_warn "systemd not found. You may need to start the NordVPN daemon manually."
    fi

    # Add the invoking user to the nordvpn group
    local target_user="${SUDO_USER:-$USER}"
    if id "$target_user" &>/dev/null; then
        usermod -aG nordvpn "$target_user"
        log_success "User '${target_user}' added to 'nordvpn' group."
    fi

    echo ""
    log_success "============================================="
    log_success " NordVPN installation complete!"
    log_success "============================================="
    echo ""
    log_info "IMPORTANT: Log out and log back in (or reboot) for group changes to take effect."
    echo ""
    log_info "Quick start:"
    log_info "  nordvpn login       - Log in to your account"
    log_info "  nordvpn connect     - Connect to VPN"
    log_info "  nordvpn disconnect  - Disconnect from VPN"
    log_info "  nordvpn settings    - View current settings"
    log_info "  nordvpn status      - Check connection status"
    echo ""
}

#---------------------------------------------------------------------------------
# Main
#---------------------------------------------------------------------------------

main() {
    echo ""
    echo "========================================="
    echo " NordVPN Installation Script"
    echo "========================================="
    echo ""

    check_root
    detect_distro
    get_pkg_family
    check_existing
    check_dependencies

    case "$PKG_FAMILY" in
        apt)    install_apt    ;;
        dnf)    install_dnf    ;;
        yum)    install_yum    ;;
        zypper) install_zypper ;;
        pacman) install_pacman ;;
    esac

    post_install
}

main "$@"

exit 0
