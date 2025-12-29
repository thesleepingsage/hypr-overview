pragma Singleton
import QtQuick
import Quickshell

Singleton {
    id: root

    // Workspace ID -> {xPercent, yPercent} position mapping (percentage-based for resolution independence)
    property var positions: ({})

    // Reactive workspace count for auto-layout calculations
    property int workspaceCount: HyprlandData.workspaces.length

    // Reserved space for stash tray (set by BoardModeWidget)
    property string reservedEdge: "none"   // "none" | "top" | "bottom" | "left" | "right"
    property real reservedSize: 0          // Pixels reserved for stash tray

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

    // Save position after drag (converts pixels to percentage, with clamping for reserved zones)
    function setPosition(workspaceId, x, y, viewWidth, viewHeight) {
        const vw = viewWidth ?? 1920
        const vh = viewHeight ?? 1080

        // Clamp position to avoid reserved zone (Gandalf enforcement)
        let clampedX = x
        let clampedY = y

        // Get cluster size for bounds checking
        const clusterSize = calculateClusterSize(vw, vh)

        switch (reservedEdge) {
            case "top":
                clampedY = Math.max(reservedSize, clampedY)
                break
            case "bottom":
                clampedY = Math.min(vh - reservedSize - clusterSize.height, clampedY)
                break
            case "left":
                clampedX = Math.max(reservedSize, clampedX)
                break
            case "right":
                clampedX = Math.min(vw - reservedSize - clusterSize.width, clampedX)
                break
        }

        // Ensure non-negative
        clampedX = Math.max(0, clampedX)
        clampedY = Math.max(0, clampedY)

        // Create shallow copy to trigger binding updates
        let newPositions = Object.assign({}, positions)
        newPositions[workspaceId] = {
            xPercent: clampedX / vw,
            yPercent: clampedY / vh
        }
        positions = newPositions
    }

    // Reset all to auto-layout (Ctrl+R)
    function resetAllPositions() {
        positions = ({})
    }

    // Calculate cluster size based on view dimensions (resolution-independent)
    function calculateClusterSize(viewWidth, viewHeight) {
        let vw = viewWidth ?? 1920
        let vh = viewHeight ?? 1080

        // Reduce available space based on reserved edge (clusters shouldn't grow into stash tray area)
        switch (reservedEdge) {
            case "top": case "bottom":
                vh -= reservedSize
                break
            case "left": case "right":
                vw -= reservedSize
                break
        }

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

    // Calculate grid-based auto-layout position (uses view dimensions, respects reserved space)
    function calculateAutoPosition(workspaceId, viewWidth, viewHeight) {
        const vw = viewWidth ?? 1920
        const vh = viewHeight ?? 1080

        // Calculate usable area after reserved space
        let usableX = 0
        let usableY = 0
        let usableWidth = vw
        let usableHeight = vh

        switch (reservedEdge) {
            case "top":
                usableY = reservedSize
                usableHeight = vh - reservedSize
                break
            case "bottom":
                usableHeight = vh - reservedSize
                break
            case "left":
                usableX = reservedSize
                usableWidth = vw - reservedSize
                break
            case "right":
                usableWidth = vw - reservedSize
                break
        }

        const count = Math.max(workspaceCount, 1)
        const cols = Math.ceil(Math.sqrt(count))
        const row = Math.floor((workspaceId - 1) / cols)
        const col = (workspaceId - 1) % cols

        const clusterSize = calculateClusterSize(vw, vh)
        const spacing = OverviewConfig.boardMode.clusterSpacing
        const padding = OverviewConfig.boardMode.padding

        return Qt.point(
            usableX + padding + col * (clusterSize.width + spacing),
            usableY + padding + row * (clusterSize.height + spacing)
        )
    }
}
