pragma Singleton
import QtQuick
import QtCore
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // --- Theme System ---
    // Priority: Hardcoded defaults → User config.json → matugen.json (wins)

    // Track if matugen theme is loaded
    property bool _matugenLoaded: false

    // User color overrides from config.json
    property var _userColors: ({})

    // Expose theme for components that want raw access
    property alias theme: themeJson

    // Overview grid settings
    property int rows: 2
    property int columns: 5
    property real scale: 0.18
    property bool orderRightLeft: false
    property bool orderBottomUp: false
    property bool centerIcons: true
    property bool showWorkspaceNumbers: true

    // Icon mappings for apps with mismatched window class / desktop entry
    property var iconMappings: ({})

    // Resolve icon path for a window class
    // Priority: mappings → desktop entry → lowercase desktop entry → class name → fallback
    function resolveIconPath(className) {
        const fallback = "application-x-executable";
        if (!className) return Quickshell.iconPath(fallback);

        // Check user-defined icon mappings first
        const mapped = root.iconMappings[className];
        if (mapped) return Quickshell.iconPath(mapped, fallback);

        // Try desktop entry lookup (uses StartupWMClass matching)
        const entry = DesktopEntries.byId(className);
        if (entry?.icon) return Quickshell.iconPath(entry.icon, fallback);

        // Try lowercase
        const lowerEntry = DesktopEntries.byId(className.toLowerCase());
        if (lowerEntry?.icon) return Quickshell.iconPath(lowerEntry.icon, fallback);

        // Fall back to class name directly
        return Quickshell.iconPath(className, fallback);
    }

    // Appearance settings
    property real backdropOpacity: 0.7
    property int windowCornerRadius: 8
    property int activeWorkspaceBorderWidth: 2
    property int animationDuration: 200

    // Grid appearance (extracted from OverviewWidget magic numbers)
    property real largeRadius: 16
    property real smallRadius: 4
    property real workspaceSpacing: 5
    property real gridPadding: 10

    // --- Colors ---
    // Priority: matugen.json → user config.json → hardcoded MD3 defaults

    // Hardcoded Material Design 3 defaults (dark theme)
    readonly property color _defaultBackground: "#111318"
    readonly property color _defaultWorkspace: "#1e2025"
    readonly property color _defaultWorkspaceHover: "#282a2f"
    readonly property color _defaultActiveBorder: "#abc7ff"
    readonly property color _defaultWorkspaceNumber: "#44474e"

    // Color resolution helper - applies priority chain with optional opacity
    function _resolveColor(themeColor, userColorKey, defaultColor, opacity) {
        const useOpacity = opacity !== undefined && opacity < 1.0;
        if (_matugenLoaded) {
            return useOpacity
                ? Qt.rgba(themeColor.r, themeColor.g, themeColor.b, opacity)
                : themeColor;
        }
        const userColor = _userColors[userColorKey];
        if (userColor) return userColor;
        return useOpacity
            ? Qt.rgba(defaultColor.r, defaultColor.g, defaultColor.b, opacity)
            : defaultColor;
    }

    // Resolved colors (uses priority chain via _resolveColor)
    property color backgroundColor: _resolveColor(themeJson.background, "backgroundColor", _defaultBackground, 0.95)
    property color workspaceColor: _resolveColor(themeJson.surface_container, "workspaceColor", _defaultWorkspace)
    property color workspaceHoverColor: _resolveColor(themeJson.surface_container_high, "workspaceHoverColor", _defaultWorkspaceHover)
    property color activeBorderColor: _resolveColor(themeJson.primary, "activeBorderColor", _defaultActiveBorder)
    property color workspaceNumberColor: _resolveColor(themeJson.outline_variant, "workspaceNumberColor", _defaultWorkspaceNumber)

    // Layout plugin detection
    // "auto" = detect at runtime, "hy3" = force hy3, "default" = force vanilla Hyprland
    property string layoutPlugin: "auto"

    // Stash tray settings
    property var stashTrays: ({
        enabled: true,
        trays: [
            { name: "quick", label: "Quick Stash" },
            { name: "later", label: "For Later" }
        ],
        modifierKey: "Shift",
        secondaryModifier: "Control",
        showEmptyTrays: false,
        position: "bottom",
        previewScale: 0.12
    })
    property bool _hy3Detected: false
    readonly property bool useHy3: layoutPlugin === "hy3" || (layoutPlugin === "auto" && _hy3Detected)

    // Config file path
    readonly property string configPath: Quickshell.env("HOME") + "/.config/hypr-overview/config.json"

    function _parseConfig(): void {
        const content = configFileView.text()
        if (!content || content.trim() === "") return

        try {
            const config = JSON.parse(content)

            // Overview settings
            if (config.overview) {
                if (config.overview.rows !== undefined) root.rows = config.overview.rows
                if (config.overview.columns !== undefined) root.columns = config.overview.columns
                if (config.overview.scale !== undefined) root.scale = config.overview.scale
                if (config.overview.orderRightLeft !== undefined) root.orderRightLeft = config.overview.orderRightLeft
                if (config.overview.orderBottomUp !== undefined) root.orderBottomUp = config.overview.orderBottomUp
                if (config.overview.centerIcons !== undefined) root.centerIcons = config.overview.centerIcons
                if (config.overview.showWorkspaceNumbers !== undefined) root.showWorkspaceNumbers = config.overview.showWorkspaceNumbers
            }

            // Appearance settings
            if (config.appearance) {
                if (config.appearance.backdropOpacity !== undefined) root.backdropOpacity = config.appearance.backdropOpacity
                if (config.appearance.windowCornerRadius !== undefined) root.windowCornerRadius = config.appearance.windowCornerRadius
                if (config.appearance.activeWorkspaceBorderWidth !== undefined) root.activeWorkspaceBorderWidth = config.appearance.activeWorkspaceBorderWidth
                if (config.appearance.animationDuration !== undefined) root.animationDuration = config.appearance.animationDuration

                // Color overrides (only used if matugen.json not present)
                if (config.appearance.colors) {
                    let colors = {};
                    if (config.appearance.colors.backgroundColor) colors.backgroundColor = config.appearance.colors.backgroundColor;
                    if (config.appearance.colors.workspaceColor) colors.workspaceColor = config.appearance.colors.workspaceColor;
                    if (config.appearance.colors.workspaceHoverColor) colors.workspaceHoverColor = config.appearance.colors.workspaceHoverColor;
                    if (config.appearance.colors.activeBorderColor) colors.activeBorderColor = config.appearance.colors.activeBorderColor;
                    if (config.appearance.colors.workspaceNumberColor) colors.workspaceNumberColor = config.appearance.colors.workspaceNumberColor;
                    root._userColors = colors;
                }
            }

            // Layout plugin override
            if (config.layoutPlugin !== undefined) root.layoutPlugin = config.layoutPlugin

            // Stash tray settings
            if (config.stashTrays) {
                let stashConfig = root.stashTrays;
                if (config.stashTrays.enabled !== undefined) stashConfig.enabled = config.stashTrays.enabled
                if (config.stashTrays.trays !== undefined) stashConfig.trays = config.stashTrays.trays
                if (config.stashTrays.modifierKey !== undefined) stashConfig.modifierKey = config.stashTrays.modifierKey
                if (config.stashTrays.secondaryModifier !== undefined) stashConfig.secondaryModifier = config.stashTrays.secondaryModifier
                if (config.stashTrays.showEmptyTrays !== undefined) stashConfig.showEmptyTrays = config.stashTrays.showEmptyTrays
                if (config.stashTrays.position !== undefined) stashConfig.position = config.stashTrays.position
                if (config.stashTrays.previewScale !== undefined) stashConfig.previewScale = config.stashTrays.previewScale
                root.stashTrays = stashConfig
            }

            // Icon mappings
            if (config.iconMappings) {
                root.iconMappings = config.iconMappings
            }

            console.log("[hypr-overview] Config loaded successfully")
        } catch (e) {
            console.error("[hypr-overview] Failed to parse config:", e)
        }
    }

    // Debounce timer for config reload
    Timer {
        id: configReloadTimer
        interval: 100
        repeat: false
        onTriggered: configFileView.reload()  // Reload file, then onLoaded fires
    }

    // Config file with live watching
    FileView {
        id: configFileView
        path: root.configPath
        watchChanges: true

        onFileChanged: configReloadTimer.restart()

        onLoaded: root._parseConfig()

        onLoadFailed: error => {
            if (error == FileViewError.FileNotFound) {
                console.log("[hypr-overview] No config file at:", root.configPath, "- using defaults")
            }
        }
    }

    // --- Matugen Theme Loading ---
    // Loads Material Design 3 colors from ~/.config/quickshell/matugen.json
    // These take highest priority when available

    FileView {
        id: matugenFileView
        path: StandardPaths.writableLocation(StandardPaths.HomeLocation) + "/.config/quickshell/matugen.json"
        watchChanges: true

        onFileChanged: reload()

        onLoaded: {
            root._matugenLoaded = true;
            console.log("[hypr-overview] Matugen theme loaded - colors will auto-update");
        }

        onLoadFailed: error => {
            root._matugenLoaded = false;
            if (error == FileViewError.FileNotFound) {
                console.log("[hypr-overview] No matugen.json found - using config/defaults");
            }
        }

        JsonAdapter {
            id: themeJson

            // Material Design 3 color tokens with MD3 dark defaults
            property color background: "#111318"
            property color surface: "#111318"
            property color surface_container: "#1e2025"
            property color surface_container_low: "#191c20"
            property color surface_container_high: "#282a2f"
            property color surface_container_highest: "#33353a"
            property color surface_bright: "#37393e"

            property color primary: "#abc7ff"
            property color primary_container: "#284777"
            property color on_primary: "#0b305f"

            property color secondary: "#bec6dc"
            property color secondary_container: "#3e4759"

            property color tertiary: "#ddbce0"
            property color tertiary_container: "#573e5c"

            property color error: "#ffb4ab"
            property color error_container: "#93000a"

            property color on_surface: "#e2e2e9"
            property color on_background: "#e2e2e9"
            property color outline: "#8e9099"
            property color outline_variant: "#44474e"

            property color scrim: "#000000"
            property color shadow: "#000000"
        }
    }

    // Detect hy3 plugin at runtime - check both hyprctl and hyprpm
    Process {
        id: hy3DetectorHyprctl
        command: ["hyprctl", "plugins", "list"]

        stdout: SplitParser {
            onRead: data => {
                if (data.toLowerCase().includes("hy3")) {
                    root._hy3Detected = true
                    console.log("[hypr-overview] hy3 detected via hyprctl plugins")
                }
            }
        }

        onExited: {
            // Also check hyprpm list for typical installations
            if (!root._hy3Detected) {
                hy3DetectorHyprpm.running = true
            } else {
                console.log("[hypr-overview] Layout mode:", root.useHy3 ? "hy3" : "default")
            }
        }
    }

    Process {
        id: hy3DetectorHyprpm
        command: ["hyprpm", "list"]

        stdout: SplitParser {
            onRead: data => {
                if (data.toLowerCase().includes("hy3")) {
                    root._hy3Detected = true
                    console.log("[hypr-overview] hy3 detected via hyprpm")
                }
            }
        }

        onExited: {
            console.log("[hypr-overview] Layout mode:", root.useHy3 ? "hy3" : "default")
        }
    }

    Component.onCompleted: {
        // FileView auto-loads and watches for changes
        hy3DetectorHyprctl.running = true
    }
}
