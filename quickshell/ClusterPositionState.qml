pragma Singleton
import QtQuick
import Quickshell

Singleton {
    id: root

    // Workspace ID -> {x, y} position mapping (session-only persistence)
    property var positions: ({})

    // Reactive workspace count for auto-layout calculations
    property int workspaceCount: HyprlandData.workspaces.length

    // Get position for workspace, with auto-layout fallback
    function getPosition(workspaceId) {
        if (positions[workspaceId]) {
            return Qt.point(positions[workspaceId].x, positions[workspaceId].y)
        }
        return calculateAutoPosition(workspaceId)
    }

    // Save position after drag
    function setPosition(workspaceId, x, y) {
        // Create shallow copy to trigger binding updates
        let newPositions = Object.assign({}, positions)
        newPositions[workspaceId] = Qt.point(x, y)
        positions = newPositions
    }

    // Reset all to auto-layout (Ctrl+R)
    function resetAllPositions() {
        positions = ({})
    }

    // Calculate grid-based auto-layout position
    function calculateAutoPosition(workspaceId) {
        const count = Math.max(workspaceCount, 1)
        const cols = Math.ceil(Math.sqrt(count))
        const row = Math.floor((workspaceId - 1) / cols)
        const col = (workspaceId - 1) % cols

        const clusterWidth = OverviewConfig.boardMode.clusterWidth
        const clusterHeight = OverviewConfig.boardMode.clusterHeight
        const spacing = OverviewConfig.boardMode.clusterSpacing
        const padding = OverviewConfig.boardMode.padding

        return Qt.point(
            padding + col * (clusterWidth + spacing),
            padding + row * (clusterHeight + spacing)
        )
    }
}
