# hypr-overview Manual

Detailed documentation for hypr-overview features and customization.

## Table of Contents

- [Overview Modes](#overview-modes)
- [Window Management](#window-management)
- [Stash Trays](#stash-trays)
- [Board Mode v2](#board-mode-v2)
- [Keyboard Navigation](#keyboard-navigation)
- [Configuration Reference](#configuration-reference)
- [IPC Commands](#ipc-commands)
- [CLI Wrapper](#cli-wrapper)
- [Customizing Keybinds](#customizing-keybinds)
- [Theming](#theming)
- [Architecture](#architecture)

## Overview Modes

hypr-overview provides two viewing modes for your workspaces:

### Grid Mode (Default)

Classic Mission Control-style grid layout:

- **Fixed Grid** - Workspaces arranged in rows × columns
- **Live Previews** - Real-time window thumbnails
- **Consistent Layout** - Predictable workspace positions

Best for: Users who prefer structure and consistent workspace positions.

### Board Mode v2

Free-form canvas with draggable workspace clusters:

- **Workspace Clusters** - Each workspace displays as a draggable "cluster" with a folder-tab header
- **Cascading Windows** - Windows stack within clusters to show workspace "shape"
- **Persistent Positioning** - Cluster positions saved across sessions
- **Resolution-Independent** - Positions stored as percentages, work across monitor changes

Best for: Users who want spatial organization and visual grouping.

Toggle between modes:
```bash
# Via IPC
hypr-overview ipc call overview toggleMode

# Via keybind (while overview is open)
# Press 'M' key
```

### First-Run Mode Selection

On first launch, a dialog prompts you to choose your preferred mode. This choice is saved to config and can be changed anytime via the mode toggle.

## Window Management

### Focus Window

Click any window preview to focus it and close the overview.

### Close Window

Middle-click a window preview to close that window.

### Move Window Between Workspaces

1. Click and drag a window preview
2. Drop it on the target workspace
3. Window moves to that workspace

### Swap Windows

1. Drag a window onto another window
2. The two windows swap positions
3. Works across workspaces

## Stash Trays

Stash trays let you "park" windows temporarily without closing them.

### How Stashing Works

1. Stashed windows move to a hidden `special:stash-{trayName}` workspace
2. They appear in the stash tray at the bottom of the overview
3. Click a stashed window to restore it to its original workspace

### Stashing Windows

| Action | Input |
|--------|-------|
| Stash to primary tray | Shift+Click on window |
| Stash to secondary tray | Ctrl+Shift+Click on window |
| Drag to stash | Drag window onto stash tray |
| Stash entire workspace | `Super+Shift+S` (keybind) |

### Restoring Windows

| Action | Input |
|--------|-------|
| Restore single window | Click stashed window in tray |
| Restore all from tray | `Super+Shift+U` (keybind) |
| Drag to restore | Drag from tray back to overview |

### Default Trays

| Tray | Modifier | Description |
|------|----------|-------------|
| Quick Stash | Shift+Click | Primary quick-access tray |
| For Later | Ctrl+Shift+Click | Secondary tray for organization |

> **Note**: Trays are purely organizational - no functional difference, no auto-expiry, no priority. They're just buckets to categorize stashed windows however you prefer.

### Custom Trays

Add or rename trays in config:
```json
{
  "stashTrays": {
    "trays": [
      { "name": "work", "label": "Work" },
      { "name": "personal", "label": "Personal" },
      { "name": "reference", "label": "Reference" }
    ]
  }
}
```

### Tray Positioning

Trays can appear on any screen edge:
```json
{
  "stashTrays": {
    "position": "bottom"  // "top", "bottom", "left", "right"
  }
}
```

## Board Mode v2

### Cluster Interactions

| Action | Input |
|--------|-------|
| Move cluster | Ctrl+Drag the cluster header |
| Reset layout | Press Ctrl+R |
| Focus workspace | Click cluster (anywhere except windows) |
| Focus window | Click window in cluster |
| Reveal empty workspace | Press `=` (configurable) |
| Hide empty workspace | Press `-` (configurable) |

### Workspace Reveal/Hide

Dynamically show or hide empty workspaces on the current monitor:

1. **Reveal (`=`)**: Shows the next empty workspace for the current monitor
   - Uses workspace→monitor mappings from your `workspaces.conf` if configured
   - After all defined workspaces are visible, creates dynamic workspaces (`hyo-ws-1`, etc.)
   - Click revealed workspaces to navigate to them

2. **Hide (`-`)**: Hides an empty workspace from the overview
   - Two modes: "stack" (LIFO - last revealed first hidden) or "highest" (highest-numbered first)
   - Never hides workspaces with windows (safety feature)
   - State persists across overview open/close cycles

**Configuration:**
```json
{
  "workspaceVisibility": {
    "revealKey": "=",
    "hideKey": "-",
    "hideMethod": "stack",
    "dynamicWorkspacePrefix": "hyo-ws",
    "workspacesConfigPath": "~/.config/hypr/configs/init/workspaces.conf"
  }
}
```

**Example:** If you're on DP-3 with workspace 4 active, and your config defines workspaces 4, 5, 6 for DP-3:
- Press `=` → reveals workspace 5
- Press `=` → reveals workspace 6
- Press `=` → creates `hyo-ws-1` on DP-3
- Press `-` → hides `hyo-ws-1`
- Press `-` → hides workspace 6

### Auto-Layout

When opening overview with no saved positions, clusters arrange automatically:
- Grid-based layout using `sqrt(workspaceCount)` columns
- Respects `clusterSpacing` and `padding` config values
- Avoids stash tray areas ("vapor barrier")

### Position Persistence

- Positions saved to cache as percentages (0.0-1.0)
- Works across resolution changes
- Reset with Ctrl+R to recalculate auto-layout

### Cluster Sizing

Controlled by config:
```json
{
  "boardMode": {
    "scale": 0.20,          // Base scale factor
    "minClusterSize": 150,  // Minimum px
    "maxClusterSize": 600   // Maximum px
  }
}
```

Scale adjusts dynamically based on workspace count:
- Fewer workspaces = larger clusters
- More workspaces = smaller clusters (within min/max bounds)

## Keyboard Navigation

### While Overview is Open

| Key | Action |
|-----|--------|
| Escape | Close overview |
| Enter | Close overview |
| M | Toggle between Grid/Board mode |
| Arrow Keys | Navigate workspaces (Grid mode) |
| Ctrl+R | Reset cluster positions (Board mode) |
| T | Toggle stash tray visibility |
| = | Reveal empty workspace (Board mode, configurable) |
| - | Hide empty workspace (Board mode, configurable) |

### Global Shortcuts

Configure in your Hyprland config:

```bash
# Toggle overview
bind = Super, Tab, global, quickshell:overviewToggle

# Stash operations
bind = Super Shift, S, global, quickshell:stashWorkspace
bind = Super Shift, U, global, quickshell:unstashQuick
```

## Configuration Reference

Config file: `~/.config/hypr-overview/config.json`

Changes take effect immediately - the config is watched and hot-reloaded.

### overview

Grid layout settings.

| Setting | Default | Description |
|---------|---------|-------------|
| `rows` | `2` | Workspace rows in grid |
| `columns` | `5` | Workspace columns in grid |
| `scale` | `0.18` | Window preview scale (0.1-0.5) |
| `orderRightLeft` | `false` | Reverse horizontal ordering |
| `orderBottomUp` | `false` | Reverse vertical ordering |
| `centerIcons` | `true` | Center app icons on previews |
| `showAppIcons` | `true` | Show app icons on window previews |
| `showWorkspaceNumbers` | `true` | Show workspace numbers |

### appearance

Visual and animation settings.

| Setting | Default | Description |
|---------|---------|-------------|
| `backdropOpacity` | `0.7` | Background dimming (0.0-1.0) |
| `windowCornerRadius` | `8` | Preview corner radius |
| `activeWorkspaceBorderWidth` | `2` | Active workspace border |
| `animationDuration` | `200` | Animation speed (ms) |

### appearance.colors

Manual color overrides (used if matugen.json not present):

| Setting | Default | Description |
|---------|---------|-------------|
| `backgroundColor` | `#111318` | Overview backdrop |
| `workspaceColor` | `#1e2025` | Workspace background |
| `workspaceHoverColor` | `#282a2f` | Workspace hover state |
| `activeBorderColor` | `#abc7ff` | Active workspace border |
| `workspaceNumberColor` | `#44474e` | Workspace numbers |

### stashTrays

Window stashing settings.

| Setting | Default | Description |
|---------|---------|-------------|
| `enabled` | `true` | Enable stash feature |
| `trays` | (see below) | Array of tray definitions |
| `modifierKey` | `"Shift"` | Primary stash modifier |
| `secondaryModifier` | `"Control"` | Secondary modifier |
| `showEmptyTrays` | `false` | Show empty trays |
| `position` | `"bottom"` | "top", "bottom", "left", "right" |
| `previewScale` | `0.12` | Stashed window preview size |
| `showAppIcons` | `true` | App-icon fallback on stash previews |

### boardMode

Board Mode settings.

| Setting | Default | Description |
|---------|---------|-------------|
| `scale` | `0.20` | Cluster size scale (0.1-0.5) |
| `minClusterSize` | `150` | Min cluster dimension (px) |
| `maxClusterSize` | `600` | Max cluster dimension (px) |
| `clusterSpacing` | `30` | Spacing in auto-layout |
| `showEmptyWorkspaces` | `true` | Show empty workspace clusters |
| `padding` | `40` | Padding from screen edges |

### modifiers

Modifier key configuration.

| Setting | Default | Description |
|---------|---------|-------------|
| `clusterDrag` | `"Ctrl"` | Modifier for cluster dragging |

### Other Settings

| Setting | Default | Description |
|---------|---------|-------------|
| `activeMode` | `"grid"` | Current mode: "grid" or "board" |
| `initialSetupDone` | `false` | First-run dialog completed |
| `iconMappings` | `{}` | Window class → icon overrides |

## IPC Commands

Control hypr-overview programmatically:

```bash
# Core control
hypr-overview ipc call overview toggle
hypr-overview ipc call overview open
hypr-overview ipc call overview close

# Mode switching
hypr-overview ipc call overview setMode grid
hypr-overview ipc call overview setMode board
hypr-overview ipc call overview toggleMode

# Stash operations
hypr-overview ipc call overview stashWorkspace
hypr-overview ipc call overview stashWorkspaceTo quick
hypr-overview ipc call overview stashWorkspaceTo later
hypr-overview ipc call overview unstashAll quick
```

> **Tip:** You can also use the short alias `hyo` instead of `hypr-overview`.

**Note:** hypr-overview must be running for IPC commands to work.

## CLI Wrapper

The `hypr-overview` (or `hyo`) wrapper provides convenient shell commands:

```bash
# Launch hypr-overview
hyo

# Reload (kill and restart)
hyo reload

# Stop/kill
hyo kill
hyo stop

# IPC passthrough
hyo ipc call overview toggle
```

### Commands

| Command | Description |
|---------|-------------|
| (no args) | Launch hypr-overview (detached) |
| `reload` | Kill existing process and relaunch |
| `kill` / `stop` | Terminate hypr-overview |
| `ipc ...` | Pass through to quickshell IPC |

### Process Management

Both `pkill -f hyo` and `pkill -f hypr-overview` work regardless of how you started it.

## Customizing Keybinds

Add to your Hyprland config:

```bash
# Toggle overview
bind = Super, Tab, global, quickshell:overviewToggle

# Alternative: Use a different key
bind = Super, grave, global, quickshell:overviewToggle

# Stash operations
bind = Super Shift, S, global, quickshell:stashWorkspace
bind = Super Shift, U, global, quickshell:unstashQuick

# Mode switching (optional)
bind = Super Shift, M, exec, hyo ipc call overview toggleMode
```

### Available GlobalShortcut Names

| Name | Action |
|------|--------|
| `overviewToggle` | Toggle overview on/off |
| `stashWorkspace` | Stash current workspace to quick tray |
| `unstashQuick` | Restore all from quick tray |

## Theming

hypr-overview uses Material Design 3 colors with automatic theme integration.

### Color Priority (highest to lowest)

1. **matugen.json** - Dynamic theming via matugen
2. **config.json colors** - Manual overrides in `appearance.colors`
3. **Defaults** - Built-in MD3 dark theme

### Manual Color Overrides

```json
{
  "appearance": {
    "colors": {
      "backgroundColor": "#1a1a2e",
      "workspaceColor": "#16213e",
      "workspaceHoverColor": "#1f3460",
      "activeBorderColor": "#e94560",
      "workspaceNumberColor": "#4a4a6a"
    }
  }
}
```

### Matugen Integration

If you use [matugen](https://github.com/InioX/matugen) for dynamic theming:

1. Ensure matugen outputs to `~/.config/quickshell/matugen.json`
2. hypr-overview automatically picks up colors
3. Colors update live when theme changes

## Architecture

```
~/.config/quickshell/hypr-overview/
├── shell.qml                 # Entry point
├── Overview.qml              # Main component (IPC + per-screen)
├── OverviewWidget.qml        # Grid Mode implementation
├── BoardModeWidget.qml       # Board Mode implementation
├── WorkspaceCluster.qml      # Cluster visual component
├── FirstRunChoice.qml        # Mode selection dialog
├── Config.qml                # Configuration singleton
├── OverviewState.qml         # Visibility/mode state
├── HyprlandData.qml          # Window/workspace data
├── StashState.qml            # Stash operations
├── StashTray.qml             # Stash tray UI
├── StashTrayContainer.qml    # Tray positioning
├── ClusterPositionState.qml  # Board Mode positions
└── qmldir                    # Module registration

~/.config/hypr-overview/
└── config.json               # User configuration

~/.local/bin/
├── hypr-overview             # CLI wrapper
└── hyo                       # Symlink to hypr-overview
```

### Key Design Patterns

- **Per-screen instances** - One visual Overview per connected monitor
- **Singleton state** - Central state management via pragma Singleton
- **Hot-reload config** - FileView watches config.json for changes
- **Resolution-independent** - Board Mode positions as percentages
- **Process-based IPC** - Uses hyprctl via Process for Hyprland commands

### Data Flow

1. User action (click/drag/key) → Handler function
2. Handler dispatches hyprctl command
3. HyprlandData updates via IPC queries
4. Bindings re-evaluate, UI updates
5. Changes persisted (config, stash state, cluster positions)
