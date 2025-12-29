pragma Singleton
import QtQuick
import Quickshell

Singleton {
    id: root

    // Workspace ID -> {xPercent, yPercent} position mapping (percentage-based for resolution independence)
    property var positions: ({})

    // Reactive workspace count for auto-layout calculations
    property int workspaceCount: HyprlandData.workspaces.length

    // Get position for workspace (converts percentage to pixels)
    function getPosition(workspaceId, viewWidth, viewHeight) {
        // Use defaults if view dimensions not available
        const vw = viewWidth ?? 1920
        const vh = viewHeight ?? 1080

        if (positions[workspaceId]) {
            return Qt.point(
                positions[workspaceId].xPercent * vw,
                positions[workspaceId].yPercent * vh
            )
        }
        return calculateAutoPosition(workspaceId, vw, vh)
    }

    // Save position after drag (converts pixels to percentage)
    function setPosition(workspaceId, x, y, viewWidth, viewHeight) {
        const vw = viewWidth ?? 1920
        const vh = viewHeight ?? 1080

        // Create shallow copy to trigger binding updates
        let newPositions = Object.assign({}, positions)
        newPositions[workspaceId] = {
            xPercent: x / vw,
            yPercent: y / vh
        }
        positions = newPositions
    }

    // Reset all to auto-layout (Ctrl+R)
    function resetAllPositions() {
        positions = ({})
    }

    // Calculate cluster size based on view dimensions (resolution-independent)
    function calculateClusterSize(viewWidth, viewHeight) {
        const vw = viewWidth ?? 1920
        const vh = viewHeight ?? 1080

        const baseScale = OverviewConfig.boardMode.scale ?? 0.20
        const count = Math.max(workspaceCount, 1)
        const scaleFactor = Math.min(2.0, Math.max(0.5, 2.0 / Math.sqrt(count)))
        const dynamicScale = baseScale * scaleFactor

        const minSize = OverviewConfig.boardMode.minClusterSize ?? 150
        const maxSize = OverviewConfig.boardMode.maxClusterSize ?? 600

        const width = Math.max(minSize, Math.min(maxSize, vw * dynamicScale))
        const height = Math.max(minSize * (vh / vw),
                               Math.min(maxSize * (vh / vw), vh * dynamicScale))

        return { width: width, height: height }
    }

    // Calculate grid-based auto-layout position (uses view dimensions)
    function calculateAutoPosition(workspaceId, viewWidth, viewHeight) {
        const vw = viewWidth ?? 1920
        const vh = viewHeight ?? 1080

        const count = Math.max(workspaceCount, 1)
        const cols = Math.ceil(Math.sqrt(count))
        const row = Math.floor((workspaceId - 1) / cols)
        const col = (workspaceId - 1) % cols

        const clusterSize = calculateClusterSize(vw, vh)
        const spacing = OverviewConfig.boardMode.clusterSpacing
        const padding = OverviewConfig.boardMode.padding

        return Qt.point(
            padding + col * (clusterSize.width + spacing),
            padding + row * (clusterSize.height + spacing)
        )
    }
}
