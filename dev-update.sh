#!/bin/bash
# Quick dev update - syncs config schema + ensures shell.qml integration
set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$HOME/.config/hypr-overview"
SHELL_QML="$HOME/.config/quickshell/shell.qml"

# Sync config schema (provides IDE tooltips)
echo "Syncing config schema..."
mkdir -p "$CONFIG_DIR"
cp "$SCRIPT_DIR/config/config.schema.json" "$CONFIG_DIR/config.schema.json"
echo "✓ Config schema updated"

# Shell.qml integration (one-time)
if [[ -f "$SHELL_QML" ]] && ! grep -q "hypr-overview" "$SHELL_QML"; then
    echo "Integrating into shell.qml..."

    # Find last import line
    last_import=$(grep -n "^import" "$SHELL_QML" | tail -1 | cut -d: -f1)

    # Find closing brace of Scope
    closing_brace=$(grep -n "^}" "$SHELL_QML" | tail -1 | cut -d: -f1)

    if [[ -n "$last_import" && -n "$closing_brace" ]]; then
        # Insert import after last import
        sed -i "${last_import}a import \"./hypr-overview\"" "$SHELL_QML"

        # Insert Overview before closing brace (line number shifted by 1 due to previous insert)
        closing_brace=$((closing_brace + 1))
        sed -i "${closing_brace}i\\  Overview {}" "$SHELL_QML"

        echo "✓ Shell integration added"
    else
        echo "⚠ Could not find insertion points - integrate manually"
    fi
else
    echo "✓ Shell already integrated"
fi

echo "Done! Restart quickshell: killall quickshell; quickshell &"
