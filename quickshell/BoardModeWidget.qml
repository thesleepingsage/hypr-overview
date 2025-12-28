import QtQuick
import Quickshell
import Quickshell.Hyprland

Item {
    id: boardCanvas
    anchors.fill: parent
    focus: true

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
    Repeater {
        id: clusterRepeater
        model: {
            // Filter workspaces based on config
            const allWorkspaces = HyprlandData.workspaces
            if (OverviewConfig.boardMode.showEmptyWorkspaces) {
                return allWorkspaces
            }
            // Only show workspaces with windows
            return allWorkspaces.filter(ws => {
                return HyprlandData.toplevelsForWorkspace(ws.id).length > 0
            })
        }

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

    // Collapse all fanned clusters when clicking background
    MouseArea {
        anchors.fill: parent
        z: -1  // Behind everything
        onClicked: {
            // Collapse all fanned clusters
            for (var i = 0; i < clusterRepeater.count; i++) {
                const item = clusterRepeater.itemAt(i)
                if (item) item.isFanned = false
            }
        }
    }
}
