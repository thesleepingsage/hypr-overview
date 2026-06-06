pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

Singleton {
    id: root

    // Track which workspaces are explicitly revealed (empty workspaces shown in board mode)
    property var revealedWorkspaces: ({})  // { workspaceId: true }

    // Track reveal order for LIFO hide mode
    property var revealStack: []  // [workspaceId1, workspaceId2, ...]

    // Parsed workspace→monitor mappings from user's workspaces.conf
    // e.g., { "DP-3": [4, 5, 6], "DP-1": [1, 2, 3], "DP-2": [7, 8, 9] }
    property var monitorWorkspaceMap: ({})

    // Dynamic workspace counter (for hyo-ws-1, hyo-ws-2, etc.)
    property int dynamicWorkspaceCounter: 1

    // Current monitor name (captured when checking)
    property string currentMonitorName: ""

    // Signal when visibility changes (for UI updates)
    signal visibilityChanged()

    // Check if a workspace is explicitly revealed
    function isRevealed(workspaceId) {
        return revealedWorkspaces[workspaceId] === true
    }

    // Get defined workspaces for a monitor from parsed config
    function getWorkspacesForMonitor(monitorName) {
        return monitorWorkspaceMap[monitorName] || []
    }

    // Get current focused monitor name
    function getCurrentMonitorName() {
        const focusedMonitor = Hyprland.focusedMonitor
        return focusedMonitor?.name || ""
    }

    // Find next empty workspace to reveal on current monitor
    function reveal() {
        const monitorName = getCurrentMonitorName()
        if (!monitorName) {
            console.log("[WorkspaceVisibility] No focused monitor")
            return false
        }

        currentMonitorName = monitorName
        const definedWorkspaces = getWorkspacesForMonitor(monitorName)
        const existingWorkspaces = HyprlandData.workspaces

        // Get IDs of workspaces that have windows
        const workspacesWithWindows = new Set()
        existingWorkspaces.forEach(ws => {
            if (HyprlandData.toplevelsForWorkspace(ws.id).length > 0) {
                workspacesWithWindows.add(ws.id)
            }
        })

        // Get IDs already visible (have windows or already revealed)
        const visibleWorkspaces = new Set()
        existingWorkspaces.forEach(ws => {
            if (workspacesWithWindows.has(ws.id) || revealedWorkspaces[ws.id]) {
                visibleWorkspaces.add(ws.id)
            }
        })

        // Find next defined workspace for this monitor that is empty and not visible
        if (definedWorkspaces.length > 0) {
            for (const wsId of definedWorkspaces) {
                if (!visibleWorkspaces.has(wsId) && !workspacesWithWindows.has(wsId)) {
                    return _revealWorkspace(wsId, monitorName)
                }
            }
        }

        // All defined workspaces are visible, create a dynamic one
        return _createDynamicWorkspace(monitorName)
    }

    // Internal: reveal an existing workspace
    function _revealWorkspace(workspaceId, monitorName) {
        // Check if workspace exists, if not create it
        const existingWs = HyprlandData.workspaceById[workspaceId]
        if (!existingWs) {
            // Workspace doesn't exist yet, create it on the target monitor
            console.log("[WorkspaceVisibility] Creating workspace", workspaceId, "on", monitorName)
            Hyprland.dispatch(HyprlandDispatch.focusWorkspace(workspaceId))
            // Switch back immediately (we just want to create it, not switch to it)
            // Note: This will create the workspace on the monitor defined in user's hyprland config
        }

        // Add to revealed set
        let newRevealed = Object.assign({}, revealedWorkspaces)
        newRevealed[workspaceId] = true
        revealedWorkspaces = newRevealed

        // Add to stack for LIFO hide
        let newStack = revealStack.slice()
        newStack.push(workspaceId)
        revealStack = newStack

        console.log("[WorkspaceVisibility] Revealed workspace", workspaceId, "on", monitorName)
        visibilityChanged()

        // Refresh HyprlandData to pick up the new workspace
        HyprlandData.updateWorkspaces()
        return true
    }

    // Internal: create a dynamic workspace on monitor
    function _createDynamicWorkspace(monitorName) {
        const prefix = OverviewConfig.workspaceVisibility?.dynamicWorkspacePrefix || "hyo-ws"
        const wsName = `${prefix}-${dynamicWorkspaceCounter}`
        dynamicWorkspaceCounter++

        console.log("[WorkspaceVisibility] Creating dynamic workspace", wsName, "on", monitorName)

        // Create named workspace on specific monitor
        Hyprland.dispatch(HyprlandDispatch.focusWorkspace(`name:${wsName}`))

        // Track it as revealed (use the name as ID since we don't know the numeric ID yet)
        // We'll need to refresh HyprlandData and find the new workspace
        visibilityChanged()
        HyprlandData.updateWorkspaces()
        return true
    }

    // Hide an empty workspace based on configured method
    function hide() {
        const method = OverviewConfig.workspaceVisibility?.hideMethod || "stack"

        if (method === "stack") {
            return _hideStackBased()
        } else {
            return _hideHighestEmpty()
        }
    }

    // Internal: stack-based hide (LIFO)
    function _hideStackBased() {
        if (revealStack.length === 0) {
            console.log("[WorkspaceVisibility] No workspaces to hide (stack empty)")
            return false
        }

        // Pop from stack until we find an empty workspace
        while (revealStack.length > 0) {
            let newStack = revealStack.slice()
            const wsId = newStack.pop()
            revealStack = newStack

            // Check if workspace is still empty
            const hasWindows = HyprlandData.toplevelsForWorkspace(wsId).length > 0
            if (hasWindows) {
                console.log("[WorkspaceVisibility] Skipping", wsId, "(has windows)")
                continue
            }

            // Remove from revealed set
            let newRevealed = Object.assign({}, revealedWorkspaces)
            delete newRevealed[wsId]
            revealedWorkspaces = newRevealed

            console.log("[WorkspaceVisibility] Hidden workspace", wsId, "(stack)")
            visibilityChanged()
            return true
        }

        console.log("[WorkspaceVisibility] No empty workspaces to hide")
        return false
    }

    // Internal: hide highest-numbered empty workspace
    function _hideHighestEmpty() {
        const monitorName = getCurrentMonitorName()
        if (!monitorName) return false

        // Find all revealed workspaces on current monitor that are empty
        const candidates = []
        for (const wsIdStr in revealedWorkspaces) {
            const wsId = parseInt(wsIdStr)
            if (isNaN(wsId)) continue

            const ws = HyprlandData.workspaceById[wsId]
            if (ws?.monitor !== monitorName) continue

            const hasWindows = HyprlandData.toplevelsForWorkspace(wsId).length > 0
            if (!hasWindows) {
                candidates.push(wsId)
            }
        }

        if (candidates.length === 0) {
            console.log("[WorkspaceVisibility] No empty workspaces to hide on", monitorName)
            return false
        }

        // Find highest-numbered
        const highest = Math.max(...candidates)

        // Remove from revealed set
        let newRevealed = Object.assign({}, revealedWorkspaces)
        delete newRevealed[highest]
        revealedWorkspaces = newRevealed

        // Also remove from stack if present
        let newStack = revealStack.filter(id => id !== highest)
        revealStack = newStack

        console.log("[WorkspaceVisibility] Hidden workspace", highest, "(highest)")
        visibilityChanged()
        return true
    }

    // Parse workspaces.conf file to build monitor→workspace mappings
    function parseWorkspacesConfig(filePath) {
        if (!filePath) {
            console.log("[WorkspaceVisibility] No workspaces config path specified")
            return
        }

        workspacesConfigLoader.path = filePath.replace("~", Quickshell.env("HOME"))
        workspacesConfigLoader.reload()
    }

    // FileView for loading workspaces.conf
    FileView {
        id: workspacesConfigLoader
        watchChanges: true

        onLoaded: {
            _parseWorkspacesFile(text())
        }

        onLoadFailed: error => {
            if (error == FileViewError.FileNotFound) {
                console.log("[WorkspaceVisibility] Workspaces config not found:", path)
            }
        }

        onFileChanged: reload()
    }

    // Internal: parse workspaces.conf content
    function _parseWorkspacesFile(content) {
        if (!content) return

        let newMap = {}
        const lines = content.split("\n")

        for (const line of lines) {
            // Match: workspace = N, monitor:MONITOR_NAME, ...
            const match = line.match(/^\s*workspace\s*=\s*(\d+)\s*,\s*monitor:([^,\s]+)/)
            if (match) {
                const wsId = parseInt(match[1])
                const monitorName = match[2]

                if (!newMap[monitorName]) {
                    newMap[monitorName] = []
                }
                newMap[monitorName].push(wsId)
            }
        }

        // Sort workspace IDs within each monitor
        for (const monitor in newMap) {
            newMap[monitor].sort((a, b) => a - b)
        }

        monitorWorkspaceMap = newMap
        console.log("[WorkspaceVisibility] Loaded workspace mappings:", JSON.stringify(monitorWorkspaceMap))
    }

    // Initialize: parse config if path is set
    Component.onCompleted: {
        const configPath = OverviewConfig.workspaceVisibility?.workspacesConfigPath
        if (configPath) {
            parseWorkspacesConfig(configPath)
        }
    }

    // Watch for config changes
    Connections {
        target: OverviewConfig
        function onWorkspaceVisibilityConfigReloaded() {
            const configPath = OverviewConfig.workspaceVisibility?.workspacesConfigPath
            if (configPath) {
                parseWorkspacesConfig(configPath)
            }
        }
    }
}
