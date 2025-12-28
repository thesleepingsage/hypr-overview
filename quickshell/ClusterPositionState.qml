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

    // Calculate dynamic cluster size (same formula as WorkspaceCluster)
    function calculateClusterSize() {
        const monitors = HyprlandData.monitors
        const monitorData = (monitors && monitors.length > 0) ? monitors[0] : { width: 1920, height: 1080 }
        const monitorWidth = monitorData.width ?? 1920
        const monitorHeight = monitorData.height ?? 1080

        const baseScale = OverviewConfig.boardMode.scale ?? 0.20
        const count = Math.max(workspaceCount, 1)
        const scaleFactor = Math.min(2.0, Math.max(0.5, 2.0 / Math.sqrt(count)))
        const dynamicScale = baseScale * scaleFactor

        const minSize = OverviewConfig.boardMode.minClusterSize ?? 150
        const maxSize = OverviewConfig.boardMode.maxClusterSize ?? 600

        const width = Math.max(minSize, Math.min(maxSize, monitorWidth * dynamicScale))
        const height = Math.max(minSize * (monitorHeight / monitorWidth),
                               Math.min(maxSize * (monitorHeight / monitorWidth), monitorHeight * dynamicScale))

        return { width: width, height: height }
    }

    // Calculate grid-based auto-layout position
    function calculateAutoPosition(workspaceId) {
        const count = Math.max(workspaceCount, 1)
        const cols = Math.ceil(Math.sqrt(count))
        const row = Math.floor((workspaceId - 1) / cols)
        const col = (workspaceId - 1) % cols

        const clusterSize = calculateClusterSize()
        const spacing = OverviewConfig.boardMode.clusterSpacing
        const padding = OverviewConfig.boardMode.padding

        return Qt.point(
            padding + col * (clusterSize.width + spacing),
            padding + row * (clusterSize.height + spacing)
        )
    }
}
