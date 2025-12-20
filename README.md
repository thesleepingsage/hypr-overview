# hypr-overview

macOS Mission Control-style workspace overview for Hyprland.

![Hyprland](https://img.shields.io/badge/Hyprland-58E1FF?style=flat-square&logo=hyprland&logoColor=black)
![Quickshell](https://img.shields.io/badge/Quickshell-QML-blue?style=flat-square)
![License](https://img.shields.io/badge/License-GPL--3.0-blue?style=flat-square)

## Features

- **Workspace Grid** - View all workspaces in a configurable grid layout
- **Window Previews** - Live window thumbnails with titles and app icons
- **Drag & Drop** - Move windows between workspaces by dragging
- **Window Swapping** - Drag windows onto each other to swap positions
- **Stash Trays** - Park windows temporarily in quick-access trays
- **Keyboard Navigation** - Arrow keys to navigate, Escape to close
- **Multi-monitor** - Works across all connected displays
- **hy3 Support** - Auto-detects hy3 plugin for enhanced swap operations

## Requirements

| Requirement | Status |
|-------------|--------|
| [Hyprland](https://hyprland.org/) | Required |
| [Quickshell](https://quickshell.outfoxxed.me/) | Required |
| [hy3](https://github.com/outfoxxed/hy3) | Optional (enhanced window swapping) |

## Installation

```bash
git clone https://github.com/thesleepingsage/hypr-overview.git
cd hypr-overview
./install.sh
```

The installer will:
1. Install QML modules to `~/.config/quickshell/hypr-overview/`
2. Create default config at `~/.config/hypr-overview/config.json`
3. Optionally integrate with your existing `shell.qml`

### Installer Options

```bash
./install.sh --help      # Show help
./install.sh --dry-run   # Preview changes without modifying files
./install.sh --update    # Quick update (preserves config)
./install.sh --link      # Symlink instead of copy (for development)
./install.sh --uninstall # Remove all components
```

## Keybinds

Add to your Hyprland config (see `keybinds.example.conf`):

```bash
# Toggle overview (Mission Control style)
bind = Super, Tab, global, quickshell:overviewToggle

# Stash operations
bind = Super Shift, S, global, quickshell:stashWorkspace
bind = Super Shift, U, global, quickshell:unstashQuick
```

## Usage

| Action | Input |
|--------|-------|
| Open/Close Overview | `Super+Tab` |
| Focus window | Click on window |
| Close window | Middle-click on window |
| Move window to workspace | Drag to target workspace |
| Swap windows | Drag window onto another window |
| Stash window | Shift+Click on window |
| Stash to secondary tray | Ctrl+Shift+Click on window |
| Navigate workspaces | Arrow keys |
| Close overview | Escape or click backdrop |

### Stash Trays

Stash trays let you "park" windows temporarily. Windows are moved to a hidden workspace and displayed in a tray at the bottom of the overview. Click a stashed window to restore it to its original workspace.

**Default trays:**
- **Quick Stash** (Shift+Click)
- **For Later** (Ctrl+Shift+Click)

> **Note:** These are just organizational labels with no functional difference between them. There's no auto-expiry, priority, or special behavior - they're simply two buckets to help you categorize stashed windows however you prefer. Rename them or add more in your config.

## Configuration

Edit `~/.config/hypr-overview/config.json`:

```json
{
    "overview": {
        "rows": 2,
        "columns": 5,
        "scale": 0.18,
        "orderRightLeft": false,
        "orderBottomUp": false,
        "centerIcons": true,
        "showWorkspaceNumbers": true
    },
    "appearance": {
        "backdropOpacity": 0.7,
        "windowCornerRadius": 8,
        "activeWorkspaceBorderWidth": 2,
        "animationDuration": 200
    },
    "stashTrays": {
        "enabled": true,
        "trays": [
            { "name": "quick", "label": "Quick Stash" },
            { "name": "later", "label": "For Later" }
        ],
        "modifierKey": "Shift",
        "secondaryModifier": "Control",
        "showEmptyTrays": false,
        "position": "bottom",
        "previewScale": 0.12
    }
}
```

### Configuration Options

| Option | Description |
|--------|-------------|
| `overview.rows` | Number of workspace rows |
| `overview.columns` | Number of workspace columns |
| `overview.scale` | Window preview scale factor |
| `overview.orderRightLeft` | Reverse horizontal ordering |
| `overview.orderBottomUp` | Reverse vertical ordering |
| `appearance.backdropOpacity` | Background dimming (0-1) |
| `stashTrays.enabled` | Enable/disable stash feature |
| `stashTrays.position` | Tray position: "bottom" or "top" |

## Integration

### Existing Quickshell Setup

If you already have a `shell.qml`, the installer can integrate automatically:

```qml
import "./hypr-overview"

Scope {
    Overview {}
    // ... your existing content
}
```

### Standalone Mode

Run separately without modifying your shell:

```bash
qs --path ~/.config/quickshell/hypr-overview &
```

Add to `hyprland.conf` for autostart:

```bash
exec-once = qs --path ~/.config/quickshell/hypr-overview &
```

## IPC Commands

Control programmatically via Quickshell IPC:

```bash
qs ipc call overview toggle
qs ipc call overview open
qs ipc call overview close
qs ipc call overview stashWorkspace
qs ipc call overview stashWorkspaceTo quick
qs ipc call overview unstashAll quick
```

## Troubleshooting

### Overview doesn't open
1. Verify quickshell is running: `pgrep quickshell`
2. Check keybind is registered: `hyprctl binds | grep overview`
3. Verify integration in shell.qml if using integrated mode

### Window thumbnails not showing
- This requires `Toplevel` capture support in Quickshell
- Ensure you're using a recent quickshell-git build

### hy3 swap not working
- hy3 is optional - basic swap works without it
- If hy3 is installed, swap uses `hy3:movewindow` for better results

## Related Projects

- [hypr-lens](https://github.com/thesleepingsage/hypr-lens) - Screenshot & screen recording for Hyprland

## License

GPL-3.0 License - see [LICENSE](LICENSE) for details.
