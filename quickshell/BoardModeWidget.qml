import QtQuick
import Quickshell
import Quickshell.Hyprland

Item {
    id: boardCanvas
    anchors.fill: parent
    focus: true

    // Monitor data for stash tray (use focused monitor)
    readonly property var focusedMonitor: Hyprland.focusedMonitor
    readonly property var monitorData: HyprlandData.monitors.find(m => m.id === focusedMonitor?.id)

    // ========== DRAG STATE (mirrors Grid Mode OverviewWidget.qml:64-68) ==========
    property int draggingFromWorkspace: -1
    property int draggingTargetWorkspace: -1
    property string draggingWindowAddress: ""
    property string draggingTargetWindowAddress: ""

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

    // Workspace clusters
    readonly property var workspaceList: {
        const allWorkspaces = HyprlandData.workspaces
        if (OverviewConfig.boardMode.showEmptyWorkspaces) {
            return allWorkspaces
        }
        return allWorkspaces.filter(ws => {
            return HyprlandData.toplevelsForWorkspace(ws.id).length > 0
        })
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

    // Stash trays (shared with Grid Mode)
    StashTrayContainer {
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        monitorData: boardCanvas.monitorData
        widgetMonitor: boardCanvas.monitorData
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
