import QtQuick
import Quickshell.Wayland
import Quickshell.Hyprland

Item {
    id: cluster

    // Required properties
    required property int workspaceId
    required property var workspaceData
    required property bool isActive
    required property int totalWorkspaces  // For dynamic sizing

    // Position management - use state position, but allow drag to override
    property point statePosition: ClusterPositionState.getPosition(workspaceId)

    // Initialize position from state on creation
    Component.onCompleted: {
        x = statePosition.x
        y = statePosition.y
    }

    // Sync position from state when not dragging and state changes
    onStatePositionChanged: {
        if (!isDragging) {
            x = statePosition.x
            y = statePosition.y
        }
    }

    // State
    property bool isDragging: false

    // Windows for this workspace
    property var windows: HyprlandData.toplevelsForWorkspace(workspaceId)
    property int windowCount: windows.length

    // ========== DYNAMIC SIZING ==========
    // Get monitor data for this workspace (use first monitor as reference)
    readonly property var clusterMonitorData: {
        const monitors = HyprlandData.monitors
        if (monitors && monitors.length > 0) {
            return monitors[0]
        }
        return { width: 1920, height: 1080, x: 0, y: 0, reserved: [0, 0, 0, 0] }
    }

    // Base scale from config
    readonly property real baseScale: OverviewConfig.boardMode.scale ?? 0.20

    // Dynamic scale: fewer workspaces = larger clusters
    // Formula: baseScale * scaleFactor where scaleFactor = 2 / sqrt(count)
    readonly property real dynamicScale: {
        const count = Math.max(1, totalWorkspaces)
        const scaleFactor = Math.min(2.0, Math.max(0.5, 2.0 / Math.sqrt(count)))
        return baseScale * scaleFactor
    }

    // Cluster dimensions maintain monitor aspect ratio
    readonly property real monitorWidth: clusterMonitorData.width ?? 1920
    readonly property real monitorHeight: clusterMonitorData.height ?? 1080
    readonly property real reservedLeft: clusterMonitorData.reserved?.[0] ?? 0
    readonly property real reservedTop: clusterMonitorData.reserved?.[1] ?? 0
    readonly property real reservedRight: clusterMonitorData.reserved?.[2] ?? 0
    readonly property real reservedBottom: clusterMonitorData.reserved?.[3] ?? 0

    // Effective monitor size (minus reserved areas like panels)
    readonly property real effectiveWidth: monitorWidth - reservedLeft - reservedRight
    readonly property real effectiveHeight: monitorHeight - reservedTop - reservedBottom

    // Final cluster size (clamped to min/max)
    readonly property real minSize: OverviewConfig.boardMode.minClusterSize ?? 150
    readonly property real maxSize: OverviewConfig.boardMode.maxClusterSize ?? 600

    width: Math.max(minSize, Math.min(maxSize, effectiveWidth * dynamicScale))
    height: Math.max(minSize * (effectiveHeight / effectiveWidth),
                     Math.min(maxSize * (effectiveHeight / effectiveWidth), effectiveHeight * dynamicScale))

    // Scale for window rendering (cluster size / monitor size)
    readonly property real clusterScale: width / effectiveWidth

    // Z-order: dragging on top, then active, then by ID
    z: isDragging ? 1000 : (isActive ? 100 : workspaceId)

    // Clipboard-style backing rectangle
    Rectangle {
        id: backing
        anchors.fill: parent
        color: OverviewConfig.workspaceColor
        border.color: isActive ? OverviewConfig.activeBorderColor : OverviewConfig.workspaceNumberColor
        border.width: isActive ? OverviewConfig.activeWorkspaceBorderWidth : 1
        radius: OverviewConfig.largeRadius
        clip: true  // Clip windows to cluster bounds (like Grid Mode)

        // Workspace label
        Text {
            text: workspaceId
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.margins: 8
            color: OverviewConfig.workspaceNumberColor
            font.bold: isActive
            font.pixelSize: 14
            z: 100  // Above windows
        }

        // Windows container - mirrors Grid Mode rendering
        Item {
            id: windowSpace
            anchors.fill: parent

            Repeater {
                id: windowRepeater
                model: cluster.windows

                delegate: OverviewWindow {
                    id: windowDelegate
                    required property var modelData
                    required property int index

                    // Grid Mode rendering (not cascade)
                    cascadeMode: false

                    // Scale matches cluster scale
                    scale: cluster.clusterScale

                    // No offset - windows position relative to cluster origin
                    xOffset: 0
                    yOffset: 0

                    // Monitor data for coordinate calculation
                    monitorData: cluster.clusterMonitorData
                    widgetMonitor: cluster.clusterMonitorData

                    // Window data
                    toplevel: modelData
                    windowData: {
                        const address = `0x${modelData.HyprlandToplevel?.address ?? ""}`
                        return HyprlandData.windowByAddress[address] ?? {}
                    }

                    // Click to focus window
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            const address = windowDelegate.windowData?.address
                            if (address) {
                                Hyprland.dispatch(`focuswindow address:${address}`)
                            }
                            OverviewState.close()
                        }
                    }
                }
            }
        }
    }

    // Visual feedback during drag
    scale: isDragging ? 1.02 : 1.0
    Behavior on scale { NumberAnimation { duration: 100 } }

    // Cluster drag area
    MouseArea {
        id: clusterDragArea
        anchors.fill: backing
        drag.target: null  // Set dynamically based on modifier
        drag.filterChildren: true  // Allow child MouseAreas to work

        onPressed: (mouse) => {
            if (OverviewConfig.isModifierActive("clusterDrag", mouse.modifiers)) {
                clusterDragArea.drag.target = cluster
                cluster.isDragging = true
            }
        }

        onReleased: {
            if (cluster.isDragging) {
                ClusterPositionState.setPosition(workspaceId, cluster.x, cluster.y)
                cluster.isDragging = false
                clusterDragArea.drag.target = null
            }
        }
    }
}
