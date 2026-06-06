# hypr-overview Configuration

Edit `config.json` in this directory to customize hypr-overview behavior.
Changes take effect immediately - the config is watched and hot-reloaded.

---

## overview

Workspace grid layout settings.

| Setting | Default | Description |
|---------|---------|-------------|
| `rows` | `2` | Number of workspace rows in the grid |
| `columns` | `5` | Number of workspace columns in the grid |
| `scale` | `0.18` | Window preview scale factor (0.1-0.5) |
| `orderRightLeft` | `false` | Reverse horizontal workspace ordering |
| `orderBottomUp` | `false` | Reverse vertical workspace ordering |
| `centerIcons` | `true` | Icon position: `true` = centered (35% of preview), `false` = top-left corner (15% of preview) |
| `showWorkspaceNumbers` | `true` | Show workspace numbers in corners |

**Grid presets:**
```json
// Standard 2x5 (10 workspaces)
"overview": { "rows": 2, "columns": 5, "scale": 0.18 }

// Compact 2x3 (6 workspaces)
"overview": { "rows": 2, "columns": 3, "scale": 0.22 }

// Large 3x4 (12 workspaces)
"overview": { "rows": 3, "columns": 4, "scale": 0.14 }
```

---

## appearance

Visual and animation settings.

| Setting | Default | Range | Description |
|---------|---------|-------|-------------|
| `backdropOpacity` | `0.7` | `0.0` - `1.0` | Background dimming level |
| `windowCornerRadius` | `8` | `0` - `20` | Window preview corner radius |
| `activeWorkspaceBorderWidth` | `2` | `0` - `10` | Active workspace border thickness |
| `animationDuration` | `200` | `0` - `500` | Animation speed in milliseconds |

### appearance.colors

Manual color overrides. Only used if matugen.json is not present.

| Setting | Default | Description |
|---------|---------|-------------|
| `backgroundColor` | `#111318` | Overview backdrop color |
| `workspaceColor` | `#1e2025` | Workspace cell background |
| `workspaceHoverColor` | `#282a2f` | Workspace hover state |
| `activeBorderColor` | `#abc7ff` | Active workspace border |
| `workspaceNumberColor` | `#44474e` | Workspace number text |

**Color priority:**
1. `~/.config/quickshell/matugen.json` (highest - dynamic theming)
2. `appearance.colors` in config.json (manual overrides)
3. Built-in MD3 dark defaults (fallback)

---

## stashTrays

Window stashing feature - temporarily park windows in quick-access trays.

| Setting | Default | Description |
|---------|---------|-------------|
| `enabled` | `true` | Enable/disable stash feature entirely |
| `trays` | (see below) | Array of tray definitions |
| `modifierKey` | `"Shift"` | Primary stash modifier (Shift+Click) |
| `secondaryModifier` | `"Control"` | Secondary modifier (Ctrl+Shift+Click) |
| `showEmptyTrays` | `false` | Show trays even when empty |
| `position` | `"bottom"` | Tray position: `"bottom"` or `"top"` |
| `previewScale` | `0.12` | Stashed window preview size |

### Tray definitions

```json
"trays": [
  { "name": "quick", "label": "Quick Stash" },
  { "name": "later", "label": "For Later" }
]
```

- `name`: Internal identifier (used by modifiers)
- `label`: Display text in the UI

**Custom trays example:**
```json
"trays": [
  { "name": "work", "label": "Work" },
  { "name": "personal", "label": "Personal" },
  { "name": "reference", "label": "Reference" }
]
```

---

## iconMappings

Fix icons for apps with mismatched window class and desktop entry.

Some apps (especially AppImages and Java apps) report a window class that doesn't match their `.desktop` file's `StartupWMClass`, causing the wrong or missing icon.

```json
"iconMappings": {
  "net-runelite-client-RuneLite": "runelite",
  "jetbrains-idea": "intellij-idea"
}
```

**Finding the window class:**
```bash
# List all window classes
hyprctl clients -j | jq '.[] | {class, title}'

# Watch for new windows
hyprctl clients -j | jq -r '.[].class' | sort -u
```

**Finding available icon names:**
```bash
# Search your icon theme
ls /usr/share/icons/Papirus/48x48/apps/ | grep -i runelite

# Common icon locations
ls ~/.local/share/icons/*/apps/
ls /usr/share/icons/hicolor/*/apps/
```

---

## activeMode

The currently selected overview mode. Persisted when switching between modes.

| Value | Description |
|-------|-------------|
| `"grid"` | Fixed grid layout (GNOME/macOS style) |
| `"board"` | Free-form draggable workspace clusters |

---

## initialSetupDone

Boolean flag indicating whether the user has completed initial mode selection.
Set to `true` after the first-run dialog is dismissed. The dialog won't appear again once this is `true`.

---

## boardMode

Settings for Board Mode (free-form cluster layout).

| Setting | Default | Range | Description |
|---------|---------|-------|-------------|
| `scale` | `0.20` | `0.1` - `0.5` | Workspace cluster size scale factor |
| `minClusterSize` | `150` | `50`+ | Minimum cluster dimension in pixels |
| `maxClusterSize` | `600` | `200`+ | Maximum cluster dimension in pixels |
| `clusterSpacing` | `30` | `0`+ | Spacing between clusters in auto-layout |
| `showEmptyWorkspaces` | `true` | - | Show clusters for workspaces with no windows |
| `padding` | `40` | `0`+ | Padding from screen edges |

---

## modifiers

Configurable modifier keys for interactions.

| Setting | Default | Description |
|---------|---------|-------------|
| `clusterDrag` | `"Ctrl"` | Modifier key to enable cluster dragging in board mode |

---

## workspaceVisibility

Settings for dynamically revealing/hiding empty workspaces in Board Mode.

| Setting | Default | Description |
|---------|---------|-------------|
| `revealKey` | `"="` | Key to reveal the next empty workspace on current monitor |
| `hideKey` | `"-"` | Key to hide an empty workspace |
| `hideMethod` | `"stack"` | Hide method: `"stack"` (LIFO - last revealed first hidden) or `"highest"` (highest-numbered first) |
| `dynamicWorkspacePrefix` | `"hyo-ws"` | Prefix for dynamically created workspaces (e.g., `hyo-ws-1`) |
| `workspacesConfigPath` | `""` | Path to your Hyprland workspaces.conf for monitor→workspace mappings |

**How it works:**
1. Press `=` in Board Mode to reveal the next empty workspace on the current monitor
2. If you have a `workspacesConfigPath` set, it uses your defined workspaces (e.g., DP-3 → 4, 5, 6)
3. After all defined workspaces are visible, creates dynamic workspaces (`hyo-ws-1`, etc.)
4. Press `-` to hide empty workspaces (never hides workspaces with windows)

**Example with workspace definitions:**
```json
"workspaceVisibility": {
  "revealKey": "=",
  "hideKey": "-",
  "hideMethod": "stack",
  "dynamicWorkspacePrefix": "hyo-ws",
  "workspacesConfigPath": "~/.config/hypr/configs/init/workspaces.conf"
}
```

**Example workspaces.conf format:**
```conf
workspace = 4, monitor:DP-3, defaultName:"Main", default:true,
workspace = 5, monitor:DP-3, defaultName:""
workspace = 6, monitor:DP-3, defaultName:""
```

---

## Full Example

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
    "previewScale": 1.0
  },
  "iconMappings": {
    "net-runelite-client-RuneLite": "runelite"
  },
  "activeMode": "grid",
  "initialSetupDone": true,
  "boardMode": {
    "scale": 0.20,
    "minClusterSize": 150,
    "maxClusterSize": 600,
    "clusterSpacing": 30,
    "showEmptyWorkspaces": true,
    "padding": 40
  },
  "modifiers": {
    "clusterDrag": "Ctrl"
  },
  "workspaceVisibility": {
    "revealKey": "=",
    "hideKey": "-",
    "hideMethod": "stack",
    "dynamicWorkspacePrefix": "hyo-ws",
    "workspacesConfigPath": ""
  }
}
```

---

## Tips

- Config hot-reloads automatically - no restart needed
- Use absolute paths if specifying any file paths
- Colors in `appearance.colors` are overridden by matugen if present
- Stash trays are organizational only - no functional difference between them
