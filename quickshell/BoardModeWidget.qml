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
    // Calculate total workspaces for dynamic sizing
    readonly property var workspaceList: {
        const allWorkspaces = HyprlandData.workspaces
        if (OverviewConfig.boardMode.showEmptyWorkspaces) {
            return allWorkspaces
        }
        return allWorkspaces.filter(ws => {
            return HyprlandData.toplevelsForWorkspace(ws.id).length > 0
        })
    }
    readonly property int workspaceCount: workspaceList.length

    Repeater {
        id: clusterRepeater
        model: boardCanvas.workspaceList

        delegate: WorkspaceCluster {
            required property var modelData

            workspaceId: modelData.id
            workspaceData: modelData
            isActive: modelData.id === HyprlandData.activeWorkspace?.id
            totalWorkspaces: boardCanvas.workspaceCount  // For dynamic sizing
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
