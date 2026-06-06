pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

/**
 * StashState - Singleton managing window stash tray state
 * Handles stashing windows to special workspaces and tracking their origins
 */
Singleton {
    id: root

    // Configuration (loaded from OverviewConfig)
    property var trays: OverviewConfig.stashTrays?.trays ?? [
        { name: "quick", label: "Quick Stash" },
        { name: "later", label: "For Later" }
    ]
    property bool enabled: OverviewConfig.stashTrays?.enabled ?? true
    property string modifierKey: OverviewConfig.stashTrays?.modifierKey ?? "Shift"
    property string secondaryModifier: OverviewConfig.stashTrays?.secondaryModifier ?? "Control"
    property bool showEmptyTrays: OverviewConfig.stashTrays?.showEmptyTrays ?? false
    property string position: OverviewConfig.stashTrays?.position ?? "bottom"
    property string verticalFillMode: OverviewConfig.stashTrays?.verticalFillMode ?? "centered"
    property real previewScale: OverviewConfig.stashTrays?.previewScale ?? 0.12
    property bool showAppIcons: OverviewConfig.stashTrays?.showAppIcons ?? true

    // Drag-drop state tracking (mirrors workspace drag pattern)
    property string draggingTargetStash: ""  // Which tray we're hovering over during drag

    /**
     * Map configured modifier key string to Qt modifier flag
     * Centralized utility for consistent modifier detection across all stash UI
     */
    function getModifierFlag(): int {
        switch (modifierKey.toLowerCase()) {
            case "shift": return Qt.ShiftModifier;
            case "control": case "ctrl": return Qt.ControlModifier;
            case "alt": return Qt.AltModifier;
            case "meta": case "super": case "mod4": return Qt.MetaModifier;
            default: return Qt.ShiftModifier;
        }
    }

    /**
     * Map secondary modifier key string to Qt modifier flag
     */
    function getSecondaryModifierFlag(): int {
        switch (secondaryModifier.toLowerCase()) {
            case "shift": return Qt.ShiftModifier;
            case "control": case "ctrl": return Qt.ControlModifier;
            case "alt": return Qt.AltModifier;
            case "meta": case "super": case "mod4": return Qt.MetaModifier;
            default: return Qt.ControlModifier;
        }
    }

    /**
     * Check if the primary stash modifier is held
     */
    function isModifierHeld(mouseModifiers: int): bool {
        return (mouseModifiers & getModifierFlag()) !== 0;
    }

    /**
     * Check if the secondary stash modifier is held
     */
    function isSecondaryModifierHeld(mouseModifiers: int): bool {
        return (mouseModifiers & getSecondaryModifierFlag()) !== 0;
    }

    // Runtime state: { "quick": [{ address, originWorkspace, originWorkspaceName, stashedAt }], ... }
    property var stashedWindows: ({})

    // Computed properties
    readonly property int totalStashedCount: {
        let count = 0;
        for (const trayName in stashedWindows) {
            count += (stashedWindows[trayName] || []).length;
        }
        return count;
    }

    // State file path
    readonly property string stateFilePath: Quickshell.env("XDG_RUNTIME_DIR") + "/hypr-overview-stash.json"

    // Signals
    signal windowStashed(string address, string trayName)
    signal windowUnstashed(string address)
    signal stateChanged()

    // In-flight operation tracking to prevent race conditions
    property var _inFlightStash: ({})     // addresses being stashed
    property var _inFlightUnstash: ({})   // addresses being unstashed
    property var _lastOperationTime: ({}) // debounce tracking per address
    readonly property int operationDebounceMs: 100

    // Pending address tracking for Process callbacks
    property string _pendingStashAddress: ""
    property string _pendingStashTray: ""
    property string _pendingUnstashAddress: ""
    property string _pendingUnstashOriginWs: ""

    // Debounce timer for state file writes
    property bool _saveQueued: false

    Timer {
        id: saveDebounce
        interval: 100
        repeat: false
        onTriggered: {
            root._doSaveState();
            root._saveQueued = false;
        }
    }

    /**
     * Stash a single window to a tray
     * Includes debouncing and in-flight tracking to prevent race conditions
     */
    function stashWindow(address: string, trayName: string, originWorkspace: int, originWorkspaceName: string): void {
        if (!enabled) return;

        // GUARD 1: Check debounce (rapid clicks)
        const now = Date.now();
        if (_lastOperationTime[address] && (now - _lastOperationTime[address]) < operationDebounceMs) {
            console.log("[StashState] Debounced stash request for:", address);
            return;
        }

        // GUARD 2: Check in-flight operations
        if (_inFlightStash[address]) {
            console.log("[StashState] Already stashing:", address);
            return;
        }
        if (_inFlightUnstash[address]) {
            console.log("[StashState] Cannot stash - unstash in progress:", address);
            return;
        }

        const trayKey = trayName || "quick";
        const specialWs = `special:stash-${trayKey}`;

        // Update state
        let newState = JSON.parse(JSON.stringify(stashedWindows));
        if (!newState[trayKey]) newState[trayKey] = [];

        // GUARD 3: Check if already stashed (existing check)
        const existing = newState[trayKey].find(w => w.address === address);
        if (existing) {
            console.log("[StashState] Window already stashed:", address);
            return;
        }

        // Mark in-flight BEFORE state update (critical ordering)
        _inFlightStash[address] = true;
        _lastOperationTime[address] = now;
        _pendingStashAddress = address;
        _pendingStashTray = trayKey;

        newState[trayKey].push({
            address: address,
            originWorkspace: originWorkspace,
            originWorkspaceName: originWorkspaceName || String(originWorkspace),
            stashedAt: now
        });

        stashedWindows = newState;

        // Execute hyprctl command
        _stashCommand.command = ["hyprctl", "dispatch", HyprlandDispatch.moveToWorkspace(address, specialWs, true)];
        _stashCommand.running = true;

        console.log("[StashState] Stashing window", address, "to", trayKey, "from workspace", originWorkspace);

        saveState();
        windowStashed(address, trayKey);
        stateChanged();
    }

    /**
     * Unstash a window back to its origin workspace
     * Includes debouncing and in-flight tracking to prevent race conditions
     */
    function unstashWindow(address: string, focusAfter: bool): void {
        // GUARD 1: Check debounce (rapid clicks)
        const now = Date.now();
        if (_lastOperationTime[address] && (now - _lastOperationTime[address]) < operationDebounceMs) {
            console.log("[StashState] Debounced unstash request for:", address);
            return;
        }

        // GUARD 2: Check in-flight operations
        if (_inFlightUnstash[address]) {
            console.log("[StashState] Already unstashing:", address);
            return;
        }
        if (_inFlightStash[address]) {
            console.log("[StashState] Cannot unstash - stash in progress:", address);
            return;
        }

        let windowData = null;
        let foundTray = null;

        // Find the window in stash
        for (const trayName in stashedWindows) {
            const windows = stashedWindows[trayName] || [];
            const idx = windows.findIndex(w => w.address === address);
            if (idx !== -1) {
                windowData = windows[idx];
                foundTray = trayName;
                break;
            }
        }

        if (!windowData) {
            console.warn("[StashState] Window not found in stash:", address);
            return;
        }

        // Mark in-flight BEFORE state update
        _inFlightUnstash[address] = true;
        _lastOperationTime[address] = now;
        _pendingUnstashAddress = address;

        // Determine target workspace
        const targetWs = windowData.originWorkspaceName.startsWith("special:")
            ? windowData.originWorkspaceName
            : windowData.originWorkspace;
        _pendingUnstashOriginWs = String(targetWs);

        // Store window data for potential rollback
        const savedWindowData = JSON.parse(JSON.stringify(windowData));
        const savedTray = foundTray;

        // Update state - remove from stash
        let newState = JSON.parse(JSON.stringify(stashedWindows));
        newState[foundTray] = newState[foundTray].filter(w => w.address !== address);
        stashedWindows = newState;

        // Execute hyprctl command (silent unless we should follow focus)
        _unstashCommand.command = ["hyprctl", "dispatch", HyprlandDispatch.moveToWorkspace(address, targetWs, !focusAfter)];
        _unstashCommand.running = true;

        // Store rollback data on the Process for potential failure recovery
        _unstashCommand.rollbackData = { windowData: savedWindowData, tray: savedTray };

        console.log("[StashState] Unstashing window", address, "to workspace", targetWs);

        saveState();
        windowUnstashed(address);
        stateChanged();
    }

    /**
     * Stash all windows from current workspace
     */
    function stashWorkspace(trayName: string): void {
        if (!enabled) return;

        const trayKey = trayName || "quick";
        const currentWs = HyprlandData.activeWorkspace;

        if (!currentWs) {
            console.warn("[StashState] No active workspace");
            return;
        }

        // Get all windows in current workspace
        const windowsInWs = HyprlandData.windowList.filter(w =>
            w.workspace.id === currentWs.id && !w.workspace.name.startsWith("special:stash-")
        );

        if (windowsInWs.length === 0) {
            console.log("[StashState] No windows to stash in workspace", currentWs.id);
            return;
        }

        // Build batch command
        const specialWs = `special:stash-${trayKey}`;
        let batchCmds = [];
        let newState = JSON.parse(JSON.stringify(stashedWindows));
        if (!newState[trayKey]) newState[trayKey] = [];

        for (const win of windowsInWs) {
            // Check if already stashed
            const existing = newState[trayKey].find(w => w.address === win.address);
            if (!existing) {
                newState[trayKey].push({
                    address: win.address,
                    originWorkspace: currentWs.id,
                    originWorkspaceName: currentWs.name,
                    stashedAt: Date.now()
                });
                batchCmds.push(`dispatch ${HyprlandDispatch.moveToWorkspace(win.address, specialWs, true)}`);
            }
        }

        if (batchCmds.length === 0) {
            console.log("[StashState] All windows already stashed");
            return;
        }

        stashedWindows = newState;

        // Execute batch command
        _batchCommand.command = ["hyprctl", "--batch", batchCmds.join(";")];
        _batchCommand.running = true;

        console.log("[StashState] Stashing", batchCmds.length, "windows from workspace", currentWs.id, "to", trayKey);

        saveState();
        stateChanged();
    }

    /**
     * Unstash all windows from a tray
     */
    function unstashAll(trayName: string): void {
        const trayKey = trayName || "quick";
        const windows = stashedWindows[trayKey] || [];

        if (windows.length === 0) {
            console.log("[StashState] No windows to unstash from", trayKey);
            return;
        }

        // Build batch command
        let batchCmds = [];
        for (const win of windows) {
            const targetWs = win.originWorkspaceName.startsWith("special:")
                ? win.originWorkspaceName
                : win.originWorkspace;
            batchCmds.push(`dispatch ${HyprlandDispatch.moveToWorkspace(win.address, targetWs, true)}`);
        }

        // Clear the tray
        let newState = JSON.parse(JSON.stringify(stashedWindows));
        newState[trayKey] = [];
        stashedWindows = newState;

        // Execute batch command
        _batchCommand.command = ["hyprctl", "--batch", batchCmds.join(";")];
        _batchCommand.running = true;

        console.log("[StashState] Unstashing all", batchCmds.length, "windows from", trayKey);

        saveState();
        stateChanged();
    }

    /**
     * Get windows for a specific tray
     */
    function getWindowsForTray(trayName: string): list<var> {
        return stashedWindows[trayName] || [];
    }

    /**
     * Get origin workspace for a stashed window
     */
    function getOriginWorkspace(address: string): int {
        for (const trayName in stashedWindows) {
            const win = (stashedWindows[trayName] || []).find(w => w.address === address);
            if (win) return win.originWorkspace;
        }
        return -1;
    }

    /**
     * Remove a window from stash (e.g., when it closes)
     */
    function removeClosedWindow(address: string): void {
        let changed = false;
        let newState = JSON.parse(JSON.stringify(stashedWindows));

        for (const trayName in newState) {
            const before = newState[trayName].length;
            newState[trayName] = newState[trayName].filter(w => w.address !== address);
            if (newState[trayName].length !== before) {
                changed = true;
                console.log("[StashState] Removed closed window", address, "from", trayName);
            }
        }

        if (changed) {
            stashedWindows = newState;
            saveState();
            stateChanged();
        }
    }

    /**
     * Queue state file save (debounced)
     */
    function saveState(): void {
        if (!_saveQueued) {
            _saveQueued = true;
            saveDebounce.restart();
        }
    }

    /**
     * Actually write state to file (atomic: temp file + rename)
     */
    function _doSaveState(): void {
        const stateData = {
            version: 1,
            trays: stashedWindows
        };

        let jsonStr;
        try {
            jsonStr = JSON.stringify(stateData);
            // Validate by parsing back (ensures no corruption)
            JSON.parse(jsonStr);
        } catch (e) {
            console.error("[StashState] Failed to serialize state:", e);
            return;
        }

        // Base64 encode to avoid shell escaping issues, atomic write via temp+rename
        const tempPath = stateFilePath + ".tmp";
        const b64 = Qt.btoa(jsonStr);

        _saveProcess.command = [
            "bash", "-c",
            `echo '${b64}' | base64 -d > '${tempPath}' && mv '${tempPath}' '${stateFilePath}'`
        ];
        _saveProcess.running = true;
    }

    /**
     * Load state from file
     */
    function loadState(): void {
        _loadExistsCheck.running = true;
    }

    function _parseLoadedState(): void {
        if (_loadBuffer.trim() === "") return;

        try {
            const state = JSON.parse(_loadBuffer);

            if (state.version !== 1) {
                console.warn("[StashState] Unknown state version:", state.version);
                return;
            }

            // Validate windows still exist in special workspaces
            const validatedState = {};
            for (const trayName in (state.trays || {})) {
                const specialWs = `special:stash-${trayName}`;
                const validWindows = (state.trays[trayName] || []).filter(win => {
                    // Check if window still exists and is in the stash workspace
                    const hyprWin = HyprlandData.windowByAddress[win.address];
                    return hyprWin && hyprWin.workspace.name === specialWs;
                });
                validatedState[trayName] = validWindows;
            }

            stashedWindows = validatedState;
            console.log("[StashState] State loaded, total stashed:", totalStashedCount);
            stateChanged();
        } catch (e) {
            console.error("[StashState] Failed to parse state:", e);
        }
    }

    // Process for single window stash
    Process {
        id: _stashCommand
        onExited: (exitCode, exitStatus) => {
            if (root._pendingStashAddress) {
                // Clear in-flight tracking
                delete root._inFlightStash[root._pendingStashAddress];

                if (exitCode !== 0) {
                    console.error("[StashState] Stash command failed:", exitCode);
                    // Rollback state on failure
                    let rollbackState = JSON.parse(JSON.stringify(root.stashedWindows));
                    if (rollbackState[root._pendingStashTray]) {
                        rollbackState[root._pendingStashTray] = rollbackState[root._pendingStashTray].filter(
                            w => w.address !== root._pendingStashAddress
                        );
                        root.stashedWindows = rollbackState;
                        root.saveState();
                        root.stateChanged();
                    }
                }
                root._pendingStashAddress = "";
                root._pendingStashTray = "";
            }
        }
    }

    // Process for single window unstash
    Process {
        id: _unstashCommand
        property var rollbackData: null

        onExited: (exitCode, exitStatus) => {
            if (root._pendingUnstashAddress) {
                // Clear in-flight tracking
                delete root._inFlightUnstash[root._pendingUnstashAddress];

                if (exitCode !== 0) {
                    console.error("[StashState] Unstash command failed:", exitCode);
                    // Rollback state on failure - re-add to stash
                    if (_unstashCommand.rollbackData) {
                        let rollbackState = JSON.parse(JSON.stringify(root.stashedWindows));
                        const tray = _unstashCommand.rollbackData.tray;
                        if (!rollbackState[tray]) rollbackState[tray] = [];
                        rollbackState[tray].push(_unstashCommand.rollbackData.windowData);
                        root.stashedWindows = rollbackState;
                        root.saveState();
                        root.stateChanged();
                    }
                }
                root._pendingUnstashAddress = "";
                root._pendingUnstashOriginWs = "";
                _unstashCommand.rollbackData = null;
            }
        }
    }

    // Process for batch operations
    Process {
        id: _batchCommand
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                console.error("[StashState] Batch command failed:", exitCode);
            }
        }
    }

    // Process for saving state (using bash to write file)
    Process {
        id: _saveProcess
        property string stdinData: ""
        // Command is set dynamically in _doSaveState
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                console.error("[StashState] Failed to save state:", exitCode);
            }
        }
    }

    // Process for checking if state file exists
    Process {
        id: _loadExistsCheck
        command: ["test", "-f", root.stateFilePath]
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                _loadProcess.running = true;
            } else {
                console.log("[StashState] No existing state file");
            }
        }
    }

    // Buffer for loading state
    property string _loadBuffer: ""

    // Process for loading state
    Process {
        id: _loadProcess
        command: ["cat", root.stateFilePath]
        stdout: SplitParser {
            splitMarker: ""
            onRead: data => {
                root._loadBuffer += data;
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                root._parseLoadedState();
            }
            root._loadBuffer = "";
        }
    }

    // Listen for window close events
    Connections {
        target: Hyprland

        function onRawEvent(event) {
            if (event.name === "closewindow") {
                const address = `0x${event.data}`;
                root.removeClosedWindow(address);
            }
        }
    }

    // Initialize on load
    Component.onCompleted: {
        // Wait for HyprlandData to be ready before loading state
        Qt.callLater(() => {
            loadState();
            console.log("[StashState] Initialized");
        });
    }
}
