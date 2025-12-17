#!/bin/bash
# hypr-overview Installer
# Workspace overview for Hyprland (Quickshell)
#
# Usage: ./install.sh [OPTIONS]

set -eu

# ==============================================================================
# Help
# ==============================================================================

show_help() {
    cat << 'EOF'
hypr-overview - Workspace Overview for Hyprland

Usage: ./install.sh [OPTIONS]

Options:
  -n, --dry-run    Preview changes without modifying files
  -h, --help       Show this help message
  -u, --uninstall  Remove all installed components

Components installed:
  1. QML modules     → ~/.config/quickshell/hypr-overview/ (symlink)
  2. Default config  → ~/.config/hypr-overview/config.json

Integration (patches user config):
  - ~/.config/quickshell/shell.qml      → Adds import + Overview component
  - ~/.config/quickshell/ScreenState.qml → Adds import + Overview per monitor

Generated (you copy manually):
  - keybinds.example.conf  → Copy contents to your Hyprland keybinds config

Requirements:
  Required: quickshell, hyprctl
EOF
    exit 0
}

# ==============================================================================
# Configuration
# ==============================================================================

# Modes
DRY_RUN=false
UNINSTALL=false

# Parse arguments
for arg in "$@"; do
    case "$arg" in
        -h|--help)      show_help ;;
        -n|--dry-run)   DRY_RUN=true ;;
        -u|--uninstall) UNINSTALL=true ;;
        *) echo "Unknown option: $arg"; echo "Use --help for usage."; exit 1 ;;
    esac
done

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

# Get script directory (where hypr-overview repo is)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Installation paths
QML_INSTALL_DIR="$HOME/.config/quickshell/hypr-overview"
CONFIG_DIR="$HOME/.config/hypr-overview"
QUICKSHELL_DIR="$HOME/.config/quickshell"
BACKUP_DIR="$HOME/.config/quickshell/backups"

# ==============================================================================
# Helper Functions
# ==============================================================================

info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; }

dry_run_prefix() {
    if $DRY_RUN; then
        echo -e "${CYAN}[DRY-RUN]${NC} "
    fi
}

ask() {
    echo -e -n "${YELLOW}[?]${NC} $1 [y/N] "
    read -r response
    [[ "$response" =~ ^[Yy]$ ]]
}

ask_yes() {
    echo -e -n "${YELLOW}[?]${NC} $1 [Y/n] "
    read -r response
    [[ ! "$response" =~ ^[Nn]$ ]]
}

banner() {
    echo -e "${CYAN}"
    cat << 'EOF'
 _                                               _
| |__  _   _ _ __  _ __       _____   _____ _ __| |_ ___  ___
| '_ \| | | | '_ \| '__|____ / _ \ \ / / _ \ '__| __/ _ \/ _ \
| | | | |_| | |_) | | |_____| (_) \ V /  __/ |  | ||  __/  __/
|_| |_|\__, | .__/|_|        \___/ \_/ \___|_|   \__\___|\___|
       |___/|_|
EOF
    echo -e "${NC}"
    echo "Workspace Overview for Hyprland"
    echo ""
}

backup_file() {
    local file="$1"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_name="$(basename "$file").hypr-overview-backup.${timestamp}"

    if [[ -f "$file" ]]; then
        mkdir -p "$BACKUP_DIR"
        if $DRY_RUN; then
            echo "$(dry_run_prefix)Would backup: $file → $BACKUP_DIR/$backup_name"
        else
            cp "$file" "$BACKUP_DIR/$backup_name"
            success "Backed up: $file"
        fi
    fi
}

# ==============================================================================
# Uninstall
# ==============================================================================

uninstall() {
    banner
    info "Uninstalling hypr-overview..."

    # Remove symlink
    if [[ -L "$QML_INSTALL_DIR" ]]; then
        if $DRY_RUN; then
            echo "$(dry_run_prefix)Would remove symlink: $QML_INSTALL_DIR"
        else
            rm "$QML_INSTALL_DIR"
            success "Removed symlink: $QML_INSTALL_DIR"
        fi
    fi

    # Remove config dir
    if [[ -d "$CONFIG_DIR" ]]; then
        if ask "Remove config directory ($CONFIG_DIR)?"; then
            if $DRY_RUN; then
                echo "$(dry_run_prefix)Would remove: $CONFIG_DIR"
            else
                rm -rf "$CONFIG_DIR"
                success "Removed: $CONFIG_DIR"
            fi
        fi
    fi

    warn "Manual cleanup required:"
    echo "  1. Remove import line from ~/.config/quickshell/shell.qml"
    echo "  2. Remove Overview {} from ~/.config/quickshell/ScreenState.qml"
    echo "  3. Remove keybind from your Hyprland config"

    success "Uninstall complete!"
    exit 0
}

# ==============================================================================
# Install Functions
# ==============================================================================

install_qml_modules() {
    info "Installing QML modules..."

    # Remove existing symlink or directory
    if [[ -e "$QML_INSTALL_DIR" ]]; then
        if [[ -L "$QML_INSTALL_DIR" ]]; then
            if $DRY_RUN; then
                echo "$(dry_run_prefix)Would remove existing symlink: $QML_INSTALL_DIR"
            else
                rm "$QML_INSTALL_DIR"
            fi
        else
            error "Target exists and is not a symlink: $QML_INSTALL_DIR"
            error "Please remove it manually and re-run the installer."
            exit 1
        fi
    fi

    # Create symlink
    if $DRY_RUN; then
        echo "$(dry_run_prefix)Would create symlink: $QML_INSTALL_DIR → $SCRIPT_DIR/quickshell"
    else
        ln -s "$SCRIPT_DIR/quickshell" "$QML_INSTALL_DIR"
        success "Created symlink: $QML_INSTALL_DIR"
    fi
}

install_config() {
    info "Installing config..."

    if $DRY_RUN; then
        echo "$(dry_run_prefix)Would create directory: $CONFIG_DIR"
        if [[ ! -f "$CONFIG_DIR/config.json" ]]; then
            echo "$(dry_run_prefix)Would copy: $SCRIPT_DIR/config/config.json → $CONFIG_DIR/config.json"
        fi
    else
        mkdir -p "$CONFIG_DIR"
        if [[ ! -f "$CONFIG_DIR/config.json" ]]; then
            cp "$SCRIPT_DIR/config/config.json" "$CONFIG_DIR/config.json"
            success "Created config: $CONFIG_DIR/config.json"
        else
            info "Config already exists, preserving: $CONFIG_DIR/config.json"
        fi
    fi
}

show_integration_instructions() {
    echo ""
    info "Manual integration required:"
    echo ""
    echo -e "${BOLD}1. Edit ~/.config/quickshell/shell.qml${NC}"
    echo "   Add import near the top (after other imports):"
    echo -e "   ${CYAN}import \"./hypr-overview\"${NC}"
    echo ""
    echo "   Add Overview {} component inside Scope (after RegionSelector if present):"
    echo -e "   ${CYAN}Overview {}${NC}"
    echo ""
    echo -e "${BOLD}2. Edit ~/.config/quickshell/ScreenState.qml${NC}"
    echo "   Add import near the top:"
    echo -e "   ${CYAN}import \"./hypr-overview\" as HO${NC}"
    echo ""
    echo "   Add Overview component inside Scope (before final closing brace):"
    echo -e "   ${CYAN}HO.Overview {${NC}"
    echo -e "   ${CYAN}    screen: root.screen${NC}"
    echo -e "   ${CYAN}}${NC}"
    echo ""
}

# ==============================================================================
# Main
# ==============================================================================

main() {
    banner

    if $UNINSTALL; then
        uninstall
    fi

    if $DRY_RUN; then
        info "Dry-run mode: no changes will be made"
        echo ""
    fi

    # Check requirements
    if ! command -v quickshell &> /dev/null; then
        warn "quickshell not found - installation may not work"
    fi

    if [[ ! -d "$QUICKSHELL_DIR" ]]; then
        error "Quickshell config directory not found: $QUICKSHELL_DIR"
        exit 1
    fi

    # Install
    install_qml_modules
    install_config

    echo ""
    success "Files installed!"

    show_integration_instructions

    info "After integration:"
    echo "  1. Add keybind to your Hyprland config (see keybinds.example.conf)"
    echo "  2. Reload Quickshell: qs reload"
    echo "  3. Press Super+Tab to open overview"
    echo ""
    info "Config location: $CONFIG_DIR/config.json"
}

main
