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
    property bool showAppIcons: true
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
        position: "bottom",              // "bottom" | "top" | "left" | "right"
        verticalFillMode: "centered",    // "centered" | "full" (for left/right positions)
        previewScale: 1.0,              // Scale multiplier for preview size (1.0 = 120x80 base)
        showAppIcons: true              // Show app-icon fallback on stashed window previews (when no live preview)
    })

    // --- Board Mode v2 Settings ---

    // Mode preference (persisted to config)
    property string activeMode: "grid"      // "grid" | "board" - currently selected overview mode
    property bool initialSetupDone: false   // false = show first-run mode selection dialog

    // Board mode visual settings
    property var boardMode: ({
        scale: 0.20,                   // Base scale factor for clusters
        minClusterSize: 150,           // Minimum cluster dimension (pixels)
        maxClusterSize: 600,           // Maximum cluster dimension (pixels)
        clusterSpacing: 30,            // Spacing between clusters in auto-layout
        showEmptyWorkspaces: true,     // Show workspaces with no windows
        padding: 40                    // Padding from screen edges
    })

    // Configurable modifier keys for interactions
    property var modifiers: ({
        clusterDrag: "Ctrl"            // Modifier for dragging clusters
    })

    // Workspace visibility settings (Board Mode reveal/hide feature)
    property var workspaceVisibility: ({
        revealKey: "=",                // Key to reveal next empty workspace
        hideKey: "-",                  // Key to hide empty workspace
        hideMethod: "stack",           // "stack" (LIFO) or "highest" (highest-numbered first)
        dynamicWorkspacePrefix: "hyo-ws",  // Prefix for dynamically created workspaces
        workspacesConfigPath: ""       // Path to workspaces.conf for monitor→workspace mappings
    })

    // Signal for workspaceVisibility config reload
    signal workspaceVisibilityConfigReloaded()

    // Helper to map key names to Qt key codes (for configurable keybinds)
    readonly property var _keyMap: ({
        "=": Qt.Key_Equal,
        "-": Qt.Key_Minus,
        "+": Qt.Key_Plus,
        "[": Qt.Key_BracketLeft,
        "]": Qt.Key_BracketRight,
        ",": Qt.Key_Comma,
        ".": Qt.Key_Period,
        "/": Qt.Key_Slash,
        "\\": Qt.Key_Backslash,
        ";": Qt.Key_Semicolon,
        "'": Qt.Key_Apostrophe,
        "`": Qt.Key_QuoteLeft
    })

    // Get Qt key code for a configured key
    function getKeyCode(keyName) {
        return _keyMap[keyName] ?? 0
    }

    // Helper to map modifier names to Qt flags
    readonly property var _modifierMap: ({
        "Ctrl": Qt.ControlModifier,
        "Alt": Qt.AltModifier,
        "Shift": Qt.ShiftModifier,
        "Super": Qt.MetaModifier,
        "Ctrl+Shift": Qt.ControlModifier | Qt.ShiftModifier,
        "Ctrl+Alt": Qt.ControlModifier | Qt.AltModifier,
        "Alt+Shift": Qt.AltModifier | Qt.ShiftModifier
    })

    // Check if configured modifier for an action is currently active
    function isModifierActive(action, eventModifiers) {
        const modifierName = modifiers[action]
        if (!modifierName) {
            console.warn("[hypr-overview] Unknown modifier action:", action)
            return false
        }

        const required = _modifierMap[modifierName] ?? 0
        // Use eventModifiers if provided, otherwise check Quickshell global state
        const active = (eventModifiers !== undefined) ? eventModifiers : 0
        return (active & required) === required
    }

    // Save mode preference to config file
    function setActiveMode(mode) {
        if (mode !== "grid" && mode !== "board") return

        root.activeMode = mode
        root.initialSetupDone = true

        // Write updated config to file
        _saveConfig()
    }

    // Toggle stash tray visibility when empty
    function toggleShowEmptyTrays() {
        let stashConfig = Object.assign({}, root.stashTrays)
        stashConfig.showEmptyTrays = !stashConfig.showEmptyTrays
        root.stashTrays = stashConfig
        _saveConfig()
    }

    // Internal: save current config state to file
    function _saveConfig() {
        // Build complete config from current state (preserves all settings)
        const config = {
            "$schema": "./config.schema.json",
            overview: {
                rows: root.rows,
                columns: root.columns,
                scale: root.scale,
                orderRightLeft: root.orderRightLeft,
                orderBottomUp: root.orderBottomUp,
                centerIcons: root.centerIcons,
                showAppIcons: root.showAppIcons,
                showWorkspaceNumbers: root.showWorkspaceNumbers
            },
            appearance: {
                backdropOpacity: root.backdropOpacity,
                windowCornerRadius: root.windowCornerRadius,
                activeWorkspaceBorderWidth: root.activeWorkspaceBorderWidth,
                animationDuration: root.animationDuration
            },
            iconMappings: root.iconMappings,
            stashTrays: root.stashTrays,
            activeMode: root.activeMode,
            initialSetupDone: root.initialSetupDone,
            boardMode: root.boardMode,
            modifiers: root.modifiers,
            workspaceVisibility: root.workspaceVisibility
        }

        const newContent = JSON.stringify(config, null, 2)
        configWriter.write(newContent)
    }

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
                if (config.overview.showAppIcons !== undefined) root.showAppIcons = config.overview.showAppIcons
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

            // Stash tray settings (shallow copy ensures binding updates trigger)
            if (config.stashTrays) {
                let stashConfig = Object.assign({}, root.stashTrays)
                if (config.stashTrays.enabled !== undefined) stashConfig.enabled = config.stashTrays.enabled
                if (config.stashTrays.trays !== undefined) stashConfig.trays = config.stashTrays.trays
                if (config.stashTrays.modifierKey !== undefined) stashConfig.modifierKey = config.stashTrays.modifierKey
                if (config.stashTrays.secondaryModifier !== undefined) stashConfig.secondaryModifier = config.stashTrays.secondaryModifier
                if (config.stashTrays.showEmptyTrays !== undefined) stashConfig.showEmptyTrays = config.stashTrays.showEmptyTrays
                if (config.stashTrays.position !== undefined) stashConfig.position = config.stashTrays.position
                if (config.stashTrays.verticalFillMode !== undefined) stashConfig.verticalFillMode = config.stashTrays.verticalFillMode
                if (config.stashTrays.previewScale !== undefined) stashConfig.previewScale = config.stashTrays.previewScale
                if (config.stashTrays.showAppIcons !== undefined) stashConfig.showAppIcons = config.stashTrays.showAppIcons
                root.stashTrays = stashConfig
            }

            // Icon mappings
            if (config.iconMappings) {
                root.iconMappings = config.iconMappings
            }

            // Mode selection
            if (config.activeMode !== undefined) root.activeMode = config.activeMode
            if (config.initialSetupDone !== undefined) root.initialSetupDone = config.initialSetupDone

            // Board mode settings (shallow copy ensures binding updates trigger)
            if (config.boardMode) {
                let boardConfig = Object.assign({}, root.boardMode)
                if (config.boardMode.scale !== undefined) boardConfig.scale = config.boardMode.scale
                if (config.boardMode.minClusterSize !== undefined) boardConfig.minClusterSize = config.boardMode.minClusterSize
                if (config.boardMode.maxClusterSize !== undefined) boardConfig.maxClusterSize = config.boardMode.maxClusterSize
                if (config.boardMode.clusterSpacing !== undefined) boardConfig.clusterSpacing = config.boardMode.clusterSpacing
                if (config.boardMode.showEmptyWorkspaces !== undefined) boardConfig.showEmptyWorkspaces = config.boardMode.showEmptyWorkspaces
                if (config.boardMode.padding !== undefined) boardConfig.padding = config.boardMode.padding
                root.boardMode = boardConfig
            }

            // Modifier keys (shallow copy ensures binding updates trigger)
            if (config.modifiers) {
                let modConfig = Object.assign({}, root.modifiers)
                if (config.modifiers.clusterDrag !== undefined) modConfig.clusterDrag = config.modifiers.clusterDrag
                root.modifiers = modConfig
            }

            // Workspace visibility settings (shallow copy ensures binding updates trigger)
            if (config.workspaceVisibility) {
                let wsConfig = Object.assign({}, root.workspaceVisibility)
                if (config.workspaceVisibility.revealKey !== undefined) wsConfig.revealKey = config.workspaceVisibility.revealKey
                if (config.workspaceVisibility.hideKey !== undefined) wsConfig.hideKey = config.workspaceVisibility.hideKey
                if (config.workspaceVisibility.hideMethod !== undefined) wsConfig.hideMethod = config.workspaceVisibility.hideMethod
                if (config.workspaceVisibility.dynamicWorkspacePrefix !== undefined) wsConfig.dynamicWorkspacePrefix = config.workspaceVisibility.dynamicWorkspacePrefix
                if (config.workspaceVisibility.workspacesConfigPath !== undefined) wsConfig.workspacesConfigPath = config.workspaceVisibility.workspacesConfigPath
                root.workspaceVisibility = wsConfig
                root.workspaceVisibilityConfigReloaded()
            }

            console.log("[hypr-overview] Config loaded successfully")
        } catch (e) {
            console.error("[hypr-overview] Failed to parse config:", e)
        }
    }

    // Process for saving config changes
    Process {
        id: configWriter
        property string jsonData: ""
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                console.error("[hypr-overview] Failed to save config:", exitCode)
            } else {
                console.log("[hypr-overview] Config saved successfully")
            }
        }

        function write(content) {
            // Write config using bash to ensure atomicity
            configWriter.command = ["bash", "-c", `mkdir -p "$(dirname '${root.configPath}')" && echo '${content}' > '${root.configPath}'`]
            configWriter.running = true
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

}
