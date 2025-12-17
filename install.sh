#!/bin/bash
# hypr-overview Installer
# macOS Mission Control-style workspace overview for Hyprland
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
  -d, --update     Quick update: refresh files, check shell integration
  -l, --link       Use symlink instead of copy (for development)

Components installed:
  1. QML modules     → ~/.config/quickshell/hypr-overview/
  2. Default config  → ~/.config/hypr-overview/config.json

Generated (you copy manually):
  - keybinds.example.conf  → Copy contents to your Hyprland keybinds config

Requirements:
  Required: quickshell
  Optional: hy3 plugin (auto-detected for swap support)
EOF
    exit 0
}

# ==============================================================================
# Configuration
# ==============================================================================

# Modes
DRY_RUN=false
UNINSTALL=false
UPDATE_MODE=false
USE_SYMLINK=false

# Parse arguments
for arg in "$@"; do
    case "$arg" in
        -h|--help)      show_help ;;
        -n|--dry-run)   DRY_RUN=true ;;
        -u|--uninstall) UNINSTALL=true ;;
        -d|--update)    UPDATE_MODE=true ;;
        -l|--link)      USE_SYMLINK=true ;;
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

dry_run_preview() {
    $DRY_RUN || return 1
    for msg in "$@"; do
        echo "$(dry_run_prefix)$msg"
    done
    return 0
}

remove_if_exists() {
    local path="$1"
    local description="$2"
    local prompt_msg=""

    if [[ "${3:-}" == "--prompt" ]]; then
        prompt_msg="${4:-}"
    fi

    [[ -e "$path" ]] || [[ -L "$path" ]] || return 0

    if [[ -n "$prompt_msg" ]]; then
        ask "$prompt_msg" || return 0
    fi

    if $DRY_RUN; then
        echo "$(dry_run_prefix)Would remove: $path"
    else
        rm -rf "$path"
        success "Removed $description"
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
| |__  _   _ _ __  _ __       _____   _____ _ __| |
| '_ \| | | | '_ \| '__|____ / _ \ \ / / _ \ '__| |
| | | | |_| | |_) | | |_____| (_) \ V /  __/ |  |_|
|_| |_|\__, | .__/|_|        \___/ \_/ \___|_|  (_)
       |___/|_|             overview
EOF
    echo -e "${NC}"
    echo "macOS Mission Control-style Overview for Hyprland"
    echo ""
}

# ==============================================================================
# Installation Detection
# ==============================================================================

is_installed() {
    [[ -d "$QML_INSTALL_DIR" ]] || [[ -L "$QML_INSTALL_DIR" ]]
}

is_shell_integrated() {
    local shell_file="$HOME/.config/quickshell/shell.qml"
    [[ -f "$shell_file" ]] && grep -q "hypr-overview" "$shell_file"
}

# ==============================================================================
# Installation Functions
# ==============================================================================

install_qml_modules() {
    info "Installing QML modules to $QML_INSTALL_DIR"

    if $USE_SYMLINK; then
        if dry_run_preview "Would create symlink: $QML_INSTALL_DIR -> $SCRIPT_DIR/quickshell"; then
            return
        fi

        # Remove existing (file, dir, or symlink)
        if [[ -e "$QML_INSTALL_DIR" ]] || [[ -L "$QML_INSTALL_DIR" ]]; then
            rm -rf "$QML_INSTALL_DIR"
        fi

        ln -s "$SCRIPT_DIR/quickshell" "$QML_INSTALL_DIR"
        success "QML modules symlinked (development mode)"
    else
        if dry_run_preview \
            "Would create: $QML_INSTALL_DIR" \
            "Would copy: $SCRIPT_DIR/quickshell/* → $QML_INSTALL_DIR/"; then
            return
        fi

        # Remove existing symlink if present
        if [[ -L "$QML_INSTALL_DIR" ]]; then
            rm "$QML_INSTALL_DIR"
        fi

        mkdir -p "$QML_INSTALL_DIR"
        cp -r "$SCRIPT_DIR/quickshell/"* "$QML_INSTALL_DIR/"
        success "QML modules installed"
    fi
}

install_config() {
    info "Installing default configuration to $CONFIG_DIR"

    if dry_run_preview \
        "Would create: $CONFIG_DIR" \
        "Would copy: $SCRIPT_DIR/config/config.json → $CONFIG_DIR/config.json"; then
        return
    fi

    mkdir -p "$CONFIG_DIR"

    if [[ -f "$CONFIG_DIR/config.json" ]]; then
        warn "Config already exists at $CONFIG_DIR/config.json"
        if ask "Overwrite with defaults?"; then
            cp "$SCRIPT_DIR/config/config.json" "$CONFIG_DIR/config.json"
            success "Config overwritten"
        else
            success "Keeping existing config"
        fi
    else
        cp "$SCRIPT_DIR/config/config.json" "$CONFIG_DIR/config.json"
        success "Default config installed"
    fi
}

generate_keybinds_example() {
    local example_file="$SCRIPT_DIR/keybinds.example.conf"

    info "Generating keybinds example file"

    if dry_run_preview "Would create: $example_file"; then
        return
    fi

    cat > "$example_file" << 'EOF'
# hypr-overview keybinds
# Copy these to your Hyprland keybinds config file
# (e.g., ~/.config/hypr/keybinds.conf or your custom keybinds file)

# Toggle overview (Mission Control style)
bind = Super, Tab, global, quickshell:overviewToggle

# Alternative: dedicated open/close
# bind = Super, grave, global, quickshell:overviewOpen
# bind = , Escape, global, quickshell:overviewClose
EOF

    success "Created $example_file"
}

# ==============================================================================
# Auto-Integration Functions
# ==============================================================================

auto_integrate_shell() {
    local shell_file="$HOME/.config/quickshell/shell.qml"
    local backup_file="${shell_file}.hypr-overview-backup.$(date +%Y%m%d_%H%M%S)"
    local temp_file="${shell_file}.hypr-overview-temp.$$"

    if dry_run_preview \
        "Would backup: $shell_file → $backup_file" \
        "Would add import and Overview to shell.qml"; then
        return 0
    fi

    # Check if already integrated
    if grep -q 'hypr-overview' "$shell_file"; then
        warn "hypr-overview already appears to be integrated in shell.qml"
        info "Skipping auto-integration"
        return 0
    fi

    # Create backup atomically
    cp "$shell_file" "$temp_file"
    mv "$temp_file" "$backup_file"
    success "Backup created: $backup_file"

    # Work on a temporary copy
    cp "$shell_file" "$temp_file"

    # Find last import line
    local last_import_line
    last_import_line=$(grep -n "^import" "$temp_file" | tail -1 | cut -d: -f1)

    if [[ -z "$last_import_line" ]]; then
        error "Could not find import statements in shell.qml"
        rm -f "$temp_file"
        return 1
    fi

    # Insert our import after the last import
    sed -i "${last_import_line}a import \"./hypr-overview\"" "$temp_file"
    info "Added import statement after line $last_import_line"

    # Find root component (Scope { or ShellRoot { or similar)
    local root_line
    root_line=$(grep -n "^Scope {\\|^ShellRoot {\\|^Variants {" "$temp_file" | head -1 | cut -d: -f1)

    if [[ -z "$root_line" ]]; then
        error "Could not find root component (Scope/ShellRoot) in shell.qml"
        rm -f "$temp_file"
        return 1
    fi

    # Insert Overview {} after the root component's opening brace
    sed -i "${root_line}a\\    Overview {}" "$temp_file"
    info "Added Overview {} after line $root_line"

    # Atomically replace the original file
    mv "$temp_file" "$shell_file"

    success "Auto-integration complete!"
    echo ""
    info "Backup saved at: $backup_file"
    return 0
}

# ==============================================================================
# Uninstall Functions
# ==============================================================================

uninstall() {
    banner
    warn "This will remove hypr-overview components"
    echo ""
    echo "Components to remove:"
    echo "  - QML modules: $QML_INSTALL_DIR"
    echo ""
    echo "Optional (will ask):"
    echo "  - Config: $CONFIG_DIR"
    echo ""

    if ! ask "Continue with uninstall?"; then
        info "Uninstall cancelled"
        exit 0
    fi

    remove_if_exists "$QML_INSTALL_DIR" "QML modules"
    remove_if_exists "$CONFIG_DIR" "config" --prompt "Remove config ($CONFIG_DIR)?"

    echo ""
    success "Uninstall complete!"
    echo ""
    warn "Remember to:"
    echo "  1. Remove keybinds from your Hyprland config"
    echo "  2. Remove import/Overview from ~/.config/quickshell/shell.qml"
}

# ==============================================================================
# Install Helper Functions
# ==============================================================================

USE_INTEGRATED=false
AUTO_INTEGRATED=false

show_next_steps() {
    local existing_shell="$HOME/.config/quickshell/shell.qml"

    echo "=============================================="
    echo "Next steps:"
    echo "=============================================="
    echo ""

    if $AUTO_INTEGRATED; then
        echo -e "1. ${BOLD}Restart quickshell:${NC}"
        echo "   killall quickshell; quickshell &"
        echo ""
        echo -e "   ${GREEN}(Integration was done automatically)${NC}"
    elif $USE_INTEGRATED; then
        echo -e "1. ${BOLD}Edit your shell.qml:${NC}"
        echo "   $existing_shell"
        echo ""
        echo "   a) Add this import near the top (with your other imports):"
        echo ""
        echo -e "      ${CYAN}import \"./hypr-overview\"${NC}"
        echo ""
        echo "   b) Add Overview inside your main component. Example:"
        echo ""
        echo -e "      ${CYAN}Scope {${NC}"
        echo -e "      ${CYAN}    Overview {}  // <-- add this line${NC}"
        echo -e "      ${CYAN}    // ... your existing content ...${NC}"
        echo -e "      ${CYAN}}${NC}"
        echo ""
        echo -e "2. ${BOLD}Restart quickshell:${NC}"
        echo "   killall quickshell; quickshell &"
    else
        echo -e "1. ${BOLD}Start hypr-overview (for this session):${NC}"
        echo "   qs --path ~/.config/quickshell/hypr-overview &"
        echo ""
        echo -e "2. ${BOLD}Add startup to your execs.conf:${NC}"
        echo "   exec-once = qs --path ~/.config/quickshell/hypr-overview &"
    fi

    local next_step=2
    if $AUTO_INTEGRATED; then
        next_step=2
    elif $USE_INTEGRATED; then
        next_step=3
    else
        next_step=3
    fi

    echo ""
    echo -e "${next_step}. ${BOLD}Add keybinds to your Hyprland config:${NC}"
    echo "   See: $SCRIPT_DIR/keybinds.example.conf"
    echo ""
    echo -e "$((next_step + 1)). ${BOLD}Reload Hyprland:${NC}"
    echo "   hyprctl reload"
    echo ""
    echo -e "$((next_step + 2)). ${BOLD}Test it:${NC}"
    echo "   Press Super+Tab to toggle overview"
    echo ""
    echo "Features:"
    echo "  - Drag windows to swap positions (same workspace)"
    echo "  - Drag windows to move between workspaces"
    echo "  - Click to focus, middle-click to close"
    echo "  - hy3 plugin auto-detected for advanced swap support"
    echo ""
}

prompt_shell_integration() {
    local existing_shell="$HOME/.config/quickshell/shell.qml"

    [[ -f "$existing_shell" ]] || return 0

    echo "----------------------------------------------"
    info "Existing quickshell shell detected at:"
    echo "   $existing_shell"
    echo ""
    echo "You can either:"
    echo "  1. INTEGRATE into your existing shell (recommended)"
    echo "  2. RUN SEPARATELY as standalone instance"
    echo ""
    read -r -p "$(echo -e "${YELLOW}[?]${NC} Integrate into existing shell? [1/y or 2/n] ")" integrate_choice
    if [[ "$integrate_choice" =~ ^[1Yy]$ ]]; then
        USE_INTEGRATED=true
        echo ""
        echo "Integration options:"
        echo "  A) AUTOMATIC - Let installer modify shell.qml"
        echo "     Backup will be created at: ${existing_shell}.hypr-overview-backup.<timestamp>"
        echo "  M) MANUAL    - Show instructions to do it yourself"
        echo ""
        read -r -p "$(echo -e "${YELLOW}[?]${NC} Attempt automatic integration? [a/M] ")" auto_choice
        if [[ "$auto_choice" =~ ^[Aa]$ ]]; then
            echo ""
            if auto_integrate_shell; then
                AUTO_INTEGRATED=true
            fi
        fi
    fi
    echo "----------------------------------------------"
    echo ""
}

# ==============================================================================
# Main Installation
# ==============================================================================

install() {
    banner

    if $DRY_RUN; then
        warn "DRY-RUN MODE - No changes will be made"
        echo ""
    fi

    # Suggest update mode if already installed
    if is_installed; then
        info "Existing hypr-overview installation detected"
        echo ""
        echo "For a quick update, use: ./install.sh --update"
        echo "  (Skips prompts for already-configured components)"
        echo ""
        if ! ask "Continue with full installation anyway?"; then
            info "Tip: Use --update for quick file refresh"
            exit 0
        fi
        echo ""
    fi

    # Check for quickshell
    if ! command -v quickshell &>/dev/null && ! command -v qs &>/dev/null; then
        error "quickshell not found!"
        echo "  Install quickshell first: paru -S quickshell-git"
        exit 1
    fi
    success "quickshell found"
    echo ""

    echo "Installation paths:"
    echo "  QML modules: $QML_INSTALL_DIR"
    echo "  Config:      $CONFIG_DIR"
    if $USE_SYMLINK; then
        echo -e "  Mode:        ${CYAN}symlink (development)${NC}"
    else
        echo "  Mode:        copy (production)"
    fi
    echo ""

    if ! ask_yes "Continue with installation?"; then
        info "Installation cancelled"
        exit 0
    fi
    echo ""

    # Install components
    install_qml_modules
    install_config

    echo ""
    generate_keybinds_example

    echo ""
    echo "=============================================="
    success "Installation complete!"
    echo "=============================================="
    echo ""

    # Shell integration and next steps
    prompt_shell_integration
    show_next_steps
}

# ==============================================================================
# Quick Update Mode
# ==============================================================================

update() {
    banner

    if $DRY_RUN; then
        warn "DRY-RUN MODE - No changes will be made"
        echo ""
    fi

    info "Update mode - refreshing hypr-overview components"
    echo ""

    # Verify it's actually installed
    if ! is_installed; then
        warn "hypr-overview is not installed. Running full installation..."
        echo ""
        install
        return
    fi

    # Check if it's a symlink (dev mode)
    if [[ -L "$QML_INSTALL_DIR" ]]; then
        success "QML modules: symlinked (development mode)"
        info "  -> $QML_INSTALL_DIR -> $(readlink "$QML_INSTALL_DIR")"

        # Verify symlink target exists
        if [[ ! -d "$(readlink -f "$QML_INSTALL_DIR")" ]]; then
            warn "Symlink target does not exist!"
            if ask "Fix symlink to point to $SCRIPT_DIR/quickshell?"; then
                rm "$QML_INSTALL_DIR"
                ln -s "$SCRIPT_DIR/quickshell" "$QML_INSTALL_DIR"
                success "Symlink fixed"
            fi
        fi
    else
        # Update QML modules (copy mode)
        info "Updating QML modules..."
        if dry_run_preview "Would update: $QML_INSTALL_DIR"; then
            :
        else
            cp -r "$SCRIPT_DIR/quickshell/"* "$QML_INSTALL_DIR/"
            success "QML modules updated"
        fi
    fi

    # Config is preserved
    if [[ -f "$CONFIG_DIR/config.json" ]]; then
        success "Config preserved (not overwritten)"
    else
        install_config
    fi

    echo ""
    echo "=============================================="
    success "Update complete!"
    echo "=============================================="
    echo ""

    # Check shell integration - offer recovery if missing
    if is_shell_integrated; then
        success "Shell integration verified"
        info "Restart quickshell to apply changes:"
        echo "  killall quickshell; quickshell &"
    else
        warn "Shell integration missing (shell.qml may have been overwritten by HDE update)"
        echo ""
        echo "  Options:"
        echo "    1) Auto-integrate into shell.qml (creates backup)"
        echo "    2) Show manual integration instructions"
        echo "    3) Skip (fix later)"
        echo ""
        echo -e -n "${YELLOW}[?]${NC} Choose option [1/2/3]: "
        read -r choice
        case "$choice" in
            1)
                auto_integrate_shell
                echo ""
                info "Restart quickshell: killall quickshell; quickshell &"
                ;;
            2)
                echo ""
                info "Add to ~/.config/quickshell/shell.qml:"
                echo ""
                echo "  // At the top with imports:"
                echo "  import \"./hypr-overview\""
                echo ""
                echo "  // Inside root component (Scope, ShellRoot, etc.):"
                echo "  Overview {}"
                echo ""
                ;;
            3|"")
                info "Skipped. Run installer without --update for full setup."
                ;;
            *)
                warn "Invalid choice. Run './install.sh' for full setup."
                ;;
        esac
    fi
    echo ""
}

# ==============================================================================
# Entry Point
# ==============================================================================

if $UNINSTALL; then
    uninstall
elif $UPDATE_MODE; then
    update
else
    install
fi
