# Security Analysis

This document explains exactly what the installer script does, demonstrating it is safe to run.

> **Note:** Line numbers referenced in this document are relative to when it was published. Future updates to the installer may shift line positions, so numbers may be inaccurate at a later date. Use the provided `grep` commands to verify current locations.

## TL;DR

| Aspect | Status |
|--------|--------|
| Root/sudo required | **No** - never uses sudo |
| Files modified | `~/.config/` only - user directories |
| Network access | **None** - no downloads, no telemetry |
| Data collection | **None** - no analytics, no phone-home |
| Reversible | **Yes** - `--uninstall` + automatic backups for shell.qml |

---

## What Gets Modified

The installer only touches files in your user directories:

| Path | Action | Purpose |
|------|--------|---------|
| `~/.config/quickshell/hypr-overview/` | Create | QML modules (UI components) |
| `~/.config/hypr-overview/config.json` | Create | User configuration file |
| `~/.config/quickshell/shell.qml` | Modify (optional) | Integration (with timestamped backup) |

**Nothing outside your user directories is ever touched.**

---

## Script Breakdown: install.sh

**638 lines total** — here's what each section does:

| Lines | Section | What It Does |
|-------|---------|--------------|
| 1-7 | Shebang + safety | `set -eu` enables strict error handling |
| 9-60 | Help & args | Parses `--help`, `--dry-run`, `--uninstall`, `--update`, `--link` |
| 62-99 | Configuration | Defines paths, colors, helper functions (no execution) |
| 100-150 | Helper functions | Utility functions for output and user prompts |
| 151-165 | Detection | Checks if already installed or integrated |
| 166-250 | Install functions | File copy operations for QML and config |
| 251-320 | Auto-integration | Optional shell.qml modification with backup |
| 321-420 | Install helper | Next steps display and integration prompts |
| 421-525 | Main install | Orchestrates installation with user prompts |
| 526-640 | Update mode | Quick update path that preserves config |

### File Operations (Lines 168-224)

All file operations use safe patterns:

```bash
# Creating directories (user-owned)
mkdir -p "$QML_INSTALL_DIR"              # Line 195
mkdir -p "$CONFIG_DIR"                   # Line 210

# Copying files (no overwrites without asking)
cp -r "$SCRIPT_DIR/quickshell/"* "$QML_INSTALL_DIR/"   # Line 196
cp "$SCRIPT_DIR/config/config.json" "$CONFIG_DIR/"     # Line 221

# Symlink mode for development
ln -s "$SCRIPT_DIR/quickshell" "$QML_INSTALL_DIR"      # Line 181
```

### Backup Creation (Lines 255-277)

Before modifying shell.qml, a timestamped backup is created:

```bash
# Line 257
local backup_file="${shell_file}.hypr-overview-backup.$(date +%Y%m%d_%H%M%S)"

# Lines 274-276 (atomic backup)
cp "$shell_file" "$temp_file"
mv "$temp_file" "$backup_file"
success "Backup created: $backup_file"
```

### Cleanup Operations (Lines 101-122)

`rm -rf` is only used for:
- Line 119: Uninstall function (removes hypr-overview directories only)
- Lines 177-178: Replacing existing installation when updating

Both are scoped to hypr-overview directories only.

---

## Safety Features

| Feature | How It Works | Lines |
|---------|--------------|-------|
| **Dry-run mode** | `--dry-run` previews all changes without executing | 45, 54, 88-98 |
| **Automatic backups** | Creates `shell.qml.hypr-overview-backup.<timestamp>` | 257, 274-276 |
| **User confirmation** | Every major action requires y/N prompt | 124-134, 214, 333 |
| **Update mode** | `--update` refreshes files, preserves config, skips prompts | 528-626 |
| **Fail-fast** | `set -eu` exits immediately on any error | 7 |
| **Dependency validation** | Checks for quickshell before proceeding | 481-487 |

---

## What This Script Does NOT Do

- **No sudo** — never requires or uses elevated privileges
- **No hidden network calls** — no curl, wget, or telemetry
- **No data collection** — no analytics or phone-home
- **No system files** — only touches `~/.config/`
- **No cron jobs** — no scheduled tasks installed
- **No services** — no systemd units or daemons
- **No PATH changes** — doesn't modify your shell PATH

---

## Verify It Yourself

### Before running — preview changes:
```bash
./install.sh --dry-run
```

### Check for dangerous patterns:
```bash
# Verify no sudo usage
grep -n "sudo" install.sh
# Expected: (nothing)

# Verify no hidden network access
grep -n "curl\|wget\|nc \|netcat\|http" install.sh
# Expected: (nothing)

# Verify all paths are in user directories
grep -n '\$HOME\|~/' install.sh | grep -v "^#" | head -20
# Expected: all paths are ~/.config/

# Verify rm -rf is scoped properly
grep -n "rm -rf" install.sh
# Expected: only in remove_if_exists function and install_qml_modules
```

### After running — check what was installed:
```bash
# See installed locations
ls -la ~/.config/quickshell/hypr-overview/
ls -la ~/.config/hypr-overview/

# Check for backup if shell.qml was modified
ls -la ~/.config/quickshell/shell.qml.hypr-overview-backup.*
```

### Full uninstall:
```bash
./install.sh --uninstall
```

---

## Questions?

If you find any security concerns, please open an issue. This script is intentionally transparent and auditable.
