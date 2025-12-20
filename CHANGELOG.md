# Changelog

All notable changes to hypr-overview are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/).

## Unreleased

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
| 0.2.0 | 2025-12-19 | Stash tray feature for parking windows |
| 0.1.0 | 2025-12-17 | Initial release with core overview functionality |
