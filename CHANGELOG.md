# Changelog

All notable changes to hypr-overview are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/).

## [Unreleased]

## 0.3.0 - 2026-06-05

### Added

- **Board Mode** - New freeform workspace layout alternative to Grid Mode
  - Workspace clusters with folder-tab headers and picture frame styling
  - Drag clusters anywhere on the canvas (Ctrl+drag)
  - Resolution-independent positioning (percentage-based storage)
  - Corner mask wedges for rounded window appearance
  - First-run mode choice dialog (Grid vs Board)
  - IPC mode toggle support
- **Stash Tray Multi-Edge Positioning** - Place stash trays on any screen edge (top, bottom, left, right)
  - Vertical layout with rotated workspace labels for left/right positions
  - Configurable `verticalFillMode`: "centered" or "full" height
  - Configurable `previewScale` for tray size customization
- **Floating Window Reposition** - Drag floating windows to reposition within Board Mode clusters
- **Cluster Drag Boundaries** - Clusters respect stash tray space via vapor-barrier collision
- **Config JSON Schema** - IDE validation and tooltips via config.schema.json
- **Workspace Reveal/Hide** - Board Mode: reveal the next empty workspace (`=`) or hide an empty one (`-`); configurable keys and hide method (LIFO stack or highest-numbered)
- **Empty Stash Tray Toggle** - Press `T` to keep stash trays visible while empty (persists to config)

### Changed

- **Reactive Hyprland data layer** - `HyprlandData` now derives window/workspace/monitor
  state from Quickshell's reactive `Hyprland.toplevels` / `.workspaces` / `.monitors`
  models (via `lastIpcObject`) instead of polling `hyprctl -j` on every event. Refreshes
  are now targeted (`refreshToplevels`/`refreshWorkspaces`/`refreshMonitors`) per event
  category and on overview open. The public `HyprlandData` interface is unchanged.
- **Native toplevel previews** - Window previews use `Hyprland.toplevels` and
  `HyprlandToplevel.wayland` directly for `ScreencopyView`, replacing the older
  `ToplevelManager` + `HyprlandToplevel` attached-property matching.
- **Stable window identity** - Drag/swap/move now anchor on the live `HyprlandToplevel`
  (address + workspace) and the `stableId` field (Hyprland >= 0.54), reducing reliance on
  position heuristics and stale polled client data for the dragged window.

### Removed

- **`BufferedProcess.qml`** - The reactive data layer no longer shells out to `hyprctl -j`,
  so the buffered JSON process runner is unused and was removed.

### Fixed

- **Screen-share thrash (Hyprland 0.55)** - The new `screencastv2` event is now filtered
  out of the data-refresh path (alongside `screencast`), so active screen sharing no
  longer triggers spurious overview data refreshes.
- **Stash Drag-Drop** - Fix drag-to-stash not working by using onEntered/onExited pattern instead of onDropped
- **Live Config Reloading** - Nested object properties (stashTrays, boardMode) now update without restart
- **Stash Race Conditions** - Debouncing and in-flight tracking prevent duplicate operations
- **Stash State Persistence** - Atomic file writes via temp file + rename, Base64 encoding
- **Config Persistence** - All settings now saved when updating config file
- **Window Positioning** - Board Mode window positions match Grid Mode behavior

## 0.2.1 - 2025-12-26

### Fixed

- **Standalone Mode** - Add missing shell.qml entry point so `qs --path` works correctly ([#1](https://github.com/thesleepingsage/hypr-overview/issues/1))

## 0.2.0 - 2025-12-19

### Added

- **Stash Tray Feature** - Park windows temporarily in quick-access trays
- **Quick Stash Tray** - Default tray for windows you'll restore soon
- **Secondary Tray** - "For Later" tray for longer-term storage
- **Stash Keybinds** - Super+Shift+S to stash workspace, Super+Shift+U to restore
- **Modifier-Click Stashing** - Shift+Click to stash, Ctrl+Shift+Click for secondary tray
- **Drag-to-Stash** - Drag windows onto stash trays to park them
- **IPC Stash Commands** - `stashWorkspace`, `stashWorkspaceTo`, `unstashAll`

### Fixed

- **Tray UI** - Windows in stash tray now grouped by origin workspace
- **Tray Layout** - Improved visual organization of stashed windows

---

## 0.1.0 - 2025-12-17

Initial release!

### Added

- **Workspace Grid** - Configurable rows x columns layout for workspace overview
- **Window Previews** - Live window thumbnails with app icons and titles
- **Drag & Drop** - Move windows between workspaces by dragging
- **Window Swapping** - Drag windows onto each other to swap positions
- **hy3 Integration** - Auto-detects hy3 plugin for enhanced swap operations
- **Multi-Monitor Support** - Overview displays on all connected monitors
- **Keyboard Navigation** - Arrow keys to navigate, Escape to close
- **Click Actions** - Click to focus, middle-click to close windows
- **Focus Grab** - Click outside overview to close (HyprlandFocusGrab)
- **GlobalShortcut** - Native Hyprland keybind registration
- **IPC Interface** - `toggle`, `open`, `close` commands via quickshell IPC
- **Installer Script** - Interactive installer with dry-run, update, and uninstall modes
- **Shell Integration** - Automatic integration into existing shell.qml with backup
- **Development Mode** - `--link` option for symlink-based development workflow
- **HDE Recovery** - Update mode detects and recovers missing shell integration
- **Configurable Appearance** - Backdrop opacity, corner radius, animation duration
- **Grid Ordering** - Options for right-to-left and bottom-to-up ordering

---

## Version History Summary

| Version | Date | Highlights |
|---------|------|------------|
| 0.3.0 | 2026-06-05 | Board Mode v2, reactive Quickshell data layer, Hyprland 0.55 compat |
| 0.2.1 | 2025-12-26 | Standalone mode fix |
| 0.2.0 | 2025-12-19 | Stash tray feature for parking windows |
| 0.1.0 | 2025-12-17 | Initial release with core overview functionality |
