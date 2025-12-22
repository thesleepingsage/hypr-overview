<h1 align="center">hypr-overview</h1>

macOS Mission Control-ish-style workspace overview for Hyprland. Inspired by and extracted from [end-4's dots-hyprland](https://github.com/end-4/dots-hyprland), with refactoring and additional features.

<p align="center">
<img src="https://img.shields.io/badge/Hyprland-58E1FF?style=flat-square&logo=hyprland&logoColor=black" alt="Hyprland">
<img src="https://img.shields.io/badge/Quickshell-QML-blue?style=flat-square" alt="Quickshell">
<img src="https://img.shields.io/badge/License-GPL--3.0-blue?style=flat-square" alt="License">
</p>

Watch the demo:
[![Video Title](https://img.youtube.com/vi/A6Ydol_6ogU/maxresdefault.jpg)](https://www.youtube.com/watch?v=A6Ydol_6ogU)

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

Config file: `~/.config/hypr-overview/config.json`

<details>
<summary><strong>Full Configuration Reference</strong></summary>

```jsonc
{
  // ─── Overview Grid ──────────────────────────────────────────
  "overview": {
    "rows": 2,                      // Number of workspace rows
    "columns": 5,                   // Number of workspace columns
    "scale": 0.18,                  // Window preview scale (0.1-0.5)
    "orderRightLeft": false,        // Reverse horizontal ordering
    "orderBottomUp": false,         // Reverse vertical ordering
    "centerIcons": true,            // Center app icons on windows
    "showWorkspaceNumbers": true    // Show workspace numbers
  },

  // ─── Appearance ─────────────────────────────────────────────
  "appearance": {
    "backdropOpacity": 0.7,         // Background dimming (0.0-1.0)
    "windowCornerRadius": 8,        // Window preview corner radius
    "activeWorkspaceBorderWidth": 2,// Active workspace border width
    "animationDuration": 200,       // Animation speed in ms
    "colors": {                     // Manual color overrides (optional)
      "backgroundColor": "#111318",
      "workspaceColor": "#1e2025",
      "workspaceHoverColor": "#282a2f",
      "activeBorderColor": "#abc7ff",
      "workspaceNumberColor": "#44474e"
    }
  },

  // ─── Stash Trays ────────────────────────────────────────────
  "stashTrays": {
    "enabled": true,                // Enable stash feature
    "trays": [                      // Define your trays
      { "name": "quick", "label": "Quick Stash" },
      { "name": "later", "label": "For Later" }
    ],
    "modifierKey": "Shift",         // Primary stash modifier
    "secondaryModifier": "Control", // Secondary tray modifier
    "showEmptyTrays": false,        // Show trays with no windows
    "position": "bottom",           // "bottom" or "top"
    "previewScale": 0.12            // Stashed window preview size
  },

  // ─── Icon Mappings ──────────────────────────────────────────
  // Fix icons for apps with mismatched window class / desktop entry
  "iconMappings": {
    "net-runelite-client-RuneLite": "runelite",
    "some-other-app": "icon-name"
  },

  // ─── Layout Plugin ──────────────────────────────────────────
  "layoutPlugin": "auto"            // "auto", "hy3", or "default"
}
```

</details>

### Quick Reference

| Section | Option | Default | Description |
|---------|--------|---------|-------------|
| `overview` | `rows` | `2` | Workspace grid rows |
| | `columns` | `5` | Workspace grid columns |
| | `scale` | `0.18` | Window preview scale factor |
| | `centerIcons` | `true` | Center icons on window previews |
| `appearance` | `backdropOpacity` | `0.7` | Background dimming (0-1) |
| | `animationDuration` | `200` | Animation speed in ms |
| `stashTrays` | `enabled` | `true` | Enable/disable stash feature |
| | `position` | `"bottom"` | Tray position: `"bottom"` or `"top"` |
| `iconMappings` | | `{}` | Window class → icon name overrides |
| `layoutPlugin` | | `"auto"` | `"auto"`, `"hy3"`, or `"default"` |

### Icon Mappings

Some apps (like AppImages) have a mismatch between their window class and desktop entry, causing missing icons. Fix them with `iconMappings`:

```json
"iconMappings": {
  "net-runelite-client-RuneLite": "runelite"
}
```

**Finding the window class:**
```bash
hyprctl clients -j | jq '.[] | {class, title}'
```

**Finding available icon names:**
```bash
ls /usr/share/icons/Papirus/48x48/apps/ | grep -i <appname>
```

### Theming

hypr-overview uses **Material Design 3** colors with automatic theme integration:

**Color Priority (highest to lowest):**
1. **matugen.json** - If `~/.config/quickshell/matugen.json` exists, colors sync automatically
2. **config.json** - Manual color overrides in `appearance.colors`
3. **Defaults** - Built-in MD3 dark theme

| Color | Default | Description |
|-------|---------|-------------|
| `backgroundColor` | `#111318` | Overview backdrop |
| `workspaceColor` | `#1e2025` | Workspace cell background |
| `workspaceHoverColor` | `#282a2f` | Workspace hover state |
| `activeBorderColor` | `#abc7ff` | Active workspace border |
| `workspaceNumberColor` | `#44474e` | Workspace number text |

**Matugen Integration:**

If you use [matugen](https://github.com/InioX/matugen) for dynamic theming, hypr-overview will automatically pick up colors from `~/.config/quickshell/matugen.json`. The colors update live when your theme changes.

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
