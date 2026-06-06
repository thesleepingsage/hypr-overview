import QtQuick
import Quickshell
import Quickshell.Hyprland
import "." as Local

Item {
    id: boardCanvas
    anchors.fill: parent
    focus: true

    // Monitor data for stash tray (use focused monitor)
    readonly property var focusedMonitor: Hyprland.focusedMonitor
    readonly property var monitorData: HyprlandData.monitors.find(m => m.id === focusedMonitor?.id)

    // ========== DRAG STATE (mirrors Grid Mode OverviewWidget.qml:64-69) ==========
    property int draggingFromWorkspace: -1
    property int draggingTargetWorkspace: -1
    property string draggingWindowAddress: ""
    property string draggingTargetWindowAddress: ""
    // Stable per-window identity (Hyprland >= 0.54) captured at drag start.
    property var draggingWindowStableId: null

    // ========== WINDOW DETECTION HELPERS ==========
    // Find window at global point across all clusters (for swap detection)
    function findWindowAtPoint(globalX, globalY, excludeAddress) {
        for (var i = 0; i < clusterRepeater.count; i++) {
            const cluster = clusterRepeater.itemAt(i)
            if (!cluster) continue

            // Check if point is within this cluster's bounds
            if (globalX < cluster.x || globalX > cluster.x + cluster.width ||
                globalY < cluster.y || globalY > cluster.y + cluster.height) {
                continue
            }

            // Search windows in this cluster
            const result = cluster.findWindowAtPoint(
                globalX - cluster.x,  // Convert to cluster-local coordinates
                globalY - cluster.y,
                excludeAddress
            )
            if (result !== "") return result
        }
        return ""
    }

    // Find which cluster contains the given global point
    function findClusterAtPoint(globalX, globalY) {
        for (var i = 0; i < clusterRepeater.count; i++) {
            const cluster = clusterRepeater.itemAt(i)
            if (!cluster) continue
            if (globalX >= cluster.x && globalX <= cluster.x + cluster.width &&
                globalY >= cluster.y && globalY <= cluster.y + cluster.height) {
                return cluster.workspaceId
            }
        }
        return -1
    }

    // ========== SWAP HANDLER (mirrors Grid Mode OverviewWidget.qml:129-148) ==========
    function handleWindowSwap(sourceAddress, targetAddress, snapBackCallback) {
        const swapCmd = Local.Config.useHy3
            ? `hy3:swapwindow address:${sourceAddress}, address:${targetAddress}`
            : `swapwindow address:${targetAddress}`
        console.log(`[Board] SWAP: ${swapCmd}`)
        Hyprland.dispatch(swapCmd)

        // Wait for HyprlandData to refresh, then snap back
        function onDataUpdated() {
            HyprlandData.windowListUpdated.disconnect(onDataUpdated)
            if (snapBackCallback) snapBackCallback()
        }
        HyprlandData.windowListUpdated.connect(onDataUpdated)
        HyprlandData.updateWindowList()
        return true
    }

    // ========== CROSS-WORKSPACE MOVE HANDLER (mirrors Grid Mode OverviewWidget.qml:176-193) ==========
    function handleWindowMove(windowAddress, targetWs, currentWs, snapBackCallback) {
        if (targetWs === -1 || targetWs === currentWs) return false

        console.log(`[Board] MOVE: ws ${currentWs} -> ${targetWs}`)
        Hyprland.dispatch(`movetoworkspacesilent ${targetWs}, address:${windowAddress}`)

        // Wait for HyprlandData to refresh, then snap back
        function onMoveDataUpdated() {
            HyprlandData.windowListUpdated.disconnect(onMoveDataUpdated)
            if (snapBackCallback) snapBackCallback()
        }
        HyprlandData.windowListUpdated.connect(onMoveDataUpdated)
        HyprlandData.updateWindowList()
        return true
    }

    // ========== FLOATING WINDOW REPOSITION (mirrors Grid Mode OverviewWidget.qml:154-173) ==========
    function handleFloatingWindowAction(windowAddress, clusterRelX, clusterRelY, windowData, clusterMonitorData, targetWs, sourceWs, snapBackCallback) {
        if (targetWs !== -1 && targetWs !== sourceWs) {
            // Cross-workspace move
            console.log(`[Board] FLOAT MOVE: ws ${sourceWs} -> ${targetWs}`)
            Hyprland.dispatch(`movetoworkspacesilent ${targetWs}, address:${windowAddress}`)

            function onFloatMoveDataUpdated() {
                HyprlandData.windowListUpdated.disconnect(onFloatMoveDataUpdated)
                if (snapBackCallback) snapBackCallback()
            }
            HyprlandData.windowListUpdated.connect(onFloatMoveDataUpdated)
            HyprlandData.updateWindowList()
            return true
        }

        // Same-workspace reposition - convert cluster-relative to absolute monitor coords
        const scale = OverviewConfig.scale

        // Get window's actual monitor (floating windows may be on different monitor than cluster)
        const winMonitorId = windowData?.monitor ?? 0
        const monitors = HyprlandData.monitors
        const winMonitorData = monitors.find(m => m.id === winMonitorId) ?? clusterMonitorData

        // Calculate width/height ratio (cluster monitor vs window's monitor)
        const widthRatio = (clusterMonitorData?.width ?? 1920) / (winMonitorData?.width ?? 1920)
        const heightRatio = (clusterMonitorData?.height ?? 1080) / (winMonitorData?.height ?? 1080)

        // Reverse the transform: cluster-relative -> monitor-relative
        const posOnMonitorX = clusterRelX / (widthRatio * scale)
        const posOnMonitorY = clusterRelY / (heightRatio * scale)

        // Convert to absolute screen coordinates
        const monitorX = winMonitorData?.x ?? 0
        const monitorY = winMonitorData?.y ?? 0
        const absoluteX = Math.round(monitorX + posOnMonitorX)
        const absoluteY = Math.round(monitorY + posOnMonitorY)

        console.log(`[Board] FLOAT REPOSITION: (${absoluteX}, ${absoluteY})`)
        Hyprland.dispatch(`movewindowpixel exact ${absoluteX} ${absoluteY}, address:${windowAddress}`)

        if (snapBackCallback) snapBackCallback()
        return true
    }

    // Background
    Rectangle {
        anchors.fill: parent
        color: OverviewConfig.backgroundColor
        opacity: OverviewConfig.backdropOpacity
    }

    // Focus grab (same as Grid Mode)
    HyprlandFocusGrab {
        active: OverviewState.isOpen && OverviewState.currentMode === "board"
        onCleared: OverviewState.close()
    }

    // Workspace clusters - show if: has windows OR is explicitly revealed
    readonly property var workspaceList: {
        const allWorkspaces = HyprlandData.workspaces

        // If showEmptyWorkspaces is true, show all (legacy behavior)
        if (OverviewConfig.boardMode.showEmptyWorkspaces) {
            return allWorkspaces
        }

        // Otherwise, filter: show if has windows OR is revealed
        return allWorkspaces.filter(ws => {
            const hasWindows = HyprlandData.toplevelsForWorkspace(ws.id).length > 0
            const isRevealed = WorkspaceVisibilityState.isRevealed(ws.id)
            return hasWindows || isRevealed
        })
    }

    // Re-evaluate workspaceList when visibility changes
    Connections {
        target: WorkspaceVisibilityState
        function onVisibilityChanged() {
            // Force workspaceList to re-evaluate by touching a dependency
            boardCanvas.workspaceList
        }
    }

    Repeater {
        id: clusterRepeater
        model: boardCanvas.workspaceList

        delegate: WorkspaceCluster {
            required property var modelData

            workspaceId: modelData.id
            workspaceData: modelData
            isActive: modelData.id === HyprlandData.activeWorkspace?.id
        }
    }

    // Stash trays with position-aware anchoring
    StashTrayContainer {
        id: stashTrayContainer
        monitorData: boardCanvas.monitorData
        widgetMonitor: boardCanvas.monitorData

        // Position-aware anchoring based on StashState.position
        anchors.top: StashState.position === "top" ? parent.top : undefined
        anchors.bottom: StashState.position === "bottom" ? parent.bottom :
            (stashTrayContainer.isVerticalLayout && StashState.verticalFillMode === "full") ? parent.bottom : undefined
        anchors.left: StashState.position === "left" ? parent.left : undefined
        anchors.right: StashState.position === "right" ? parent.right : undefined
        anchors.horizontalCenter: !stashTrayContainer.isVerticalLayout ? parent.horizontalCenter : undefined
        anchors.verticalCenter: stashTrayContainer.isVerticalLayout && StashState.verticalFillMode === "centered" ? parent.verticalCenter : undefined
    }

    // Sync stash tray bounds for vapor barrier collision
    Binding {
        target: ClusterPositionState
        property: "stashTrayBounds"
        value: stashTrayContainer.shouldShow
            ? Qt.rect(stashTrayContainer.x, stashTrayContainer.y,
                      stashTrayContainer.width, stashTrayContainer.height)
            : Qt.rect(0, 0, 0, 0)
    }

    // Keyboard shortcuts
    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Escape) {
            OverviewState.close()
            event.accepted = true
        }
        // Ctrl+R: Reset layout
        if (event.key === Qt.Key_R && (event.modifiers & Qt.ControlModifier)) {
            ClusterPositionState.resetAllPositions()
            event.accepted = true
        }
        // M: Toggle mode (while overview is open)
        if (event.key === Qt.Key_M) {
            OverviewState.toggleMode()
            event.accepted = true
        }
        // T: Toggle stash tray visibility when empty (persists to config)
        if (event.key === Qt.Key_T) {
            OverviewConfig.toggleShowEmptyTrays()
            event.accepted = true
        }
        // O: Settings (placeholder)
        if (event.key === Qt.Key_O) {
            console.log("[BoardMode] Settings not implemented")
            event.accepted = true
        }
        // Reveal workspace (configurable, default: =)
        const revealKey = OverviewConfig.getKeyCode(OverviewConfig.workspaceVisibility.revealKey)
        if (revealKey && event.key === revealKey) {
            WorkspaceVisibilityState.reveal()
            event.accepted = true
        }
        // Hide workspace (configurable, default: -)
        const hideKey = OverviewConfig.getKeyCode(OverviewConfig.workspaceVisibility.hideKey)
        if (hideKey && event.key === hideKey) {
            WorkspaceVisibilityState.hide()
            event.accepted = true
        }
    }

    // Background click closes overview
    MouseArea {
        anchors.fill: parent
        z: -1  // Behind everything
        onClicked: {
            OverviewState.close()
        }
    }

}
