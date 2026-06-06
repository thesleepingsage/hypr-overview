pragma Singleton
import QtQuick
import Quickshell

Singleton {
    id: root

    // Workspace ID -> {xPercent, yPercent} position mapping (percentage-based for resolution independence)
    property var positions: ({})

    // Reactive workspace count for auto-layout calculations
    property int workspaceCount: HyprlandData.workspaces.length

    // Stash tray bounds for vapor barrier collision (set by BoardModeWidget)
    property rect stashTrayBounds: Qt.rect(0, 0, 0, 0)
    property real vaporBarrier: 5  // px buffer around tray

    // Check if two rects intersect
    function rectsIntersect(ax, ay, aw, ah, bx, by, bw, bh) {
        return ax < bx + bw && ax + aw > bx && ay < by + bh && ay + ah > by
    }

    // Push cluster away from tray if overlapping
    function clampToAvoidTray(x, y, w, h) {
        if (stashTrayBounds.width === 0) return Qt.point(x, y)

        console.log("[VaporBarrier] tray bounds:", stashTrayBounds.x, stashTrayBounds.y, stashTrayBounds.width, stashTrayBounds.height)
        console.log("[VaporBarrier] cluster:", x, y, w, h)

        // Expand tray bounds by vapor barrier
        const tx = stashTrayBounds.x - vaporBarrier
        const ty = stashTrayBounds.y - vaporBarrier
        const tw = stashTrayBounds.width + vaporBarrier * 2
        const th = stashTrayBounds.height + vaporBarrier * 2

        if (!rectsIntersect(x, y, w, h, tx, ty, tw, th)) return Qt.point(x, y)

        // Push away from tray based on cluster position relative to tray center
        const clusterCenterY = y + h / 2
        const trayCenterY = ty + th / 2
        if (clusterCenterY < trayCenterY) {
            return Qt.point(x, ty - h)  // Push up
        } else {
            return Qt.point(x, ty + th)  // Push down
        }
    }

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

    // Save position after drag (converts pixels to percentage, with vapor barrier collision)
    function setPosition(workspaceId, x, y, viewWidth, viewHeight) {
        const vw = viewWidth ?? 1920
        const vh = viewHeight ?? 1080

        // Get cluster size for bounds checking
        const clusterSize = calculateClusterSize(vw, vh)

        // Ensure within screen bounds
        let clampedX = Math.max(0, Math.min(vw - clusterSize.width, x))
        let clampedY = Math.max(0, Math.min(vh - clusterSize.height, y))

        // Apply vapor barrier collision with stash tray
        const clamped = clampToAvoidTray(clampedX, clampedY, clusterSize.width, clusterSize.height)
        clampedX = clamped.x
        clampedY = clamped.y

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
