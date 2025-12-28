import QtQuick
import Quickshell.Wayland
import Quickshell.Hyprland

Item {
    id: cluster

    // Required properties
    required property int workspaceId
    required property var workspaceData
    required property bool isActive

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

    // Sizing from config
    width: OverviewConfig.boardMode.clusterWidth
    height: OverviewConfig.boardMode.clusterHeight

    // State
    property bool isDragging: false
    property bool isFanned: false

    // Windows for this workspace
    property var windows: HyprlandData.toplevelsForWorkspace(workspaceId)
    property int windowCount: windows.length

    // Cascade layout settings
    readonly property real cascadeOffsetX: OverviewConfig.boardMode.cascadeOffsetX
    readonly property real cascadeOffsetY: OverviewConfig.boardMode.cascadeOffsetY
    readonly property real windowPadding: 10

    // Calculate thumbnail size to fit within cluster (accounting for cascade offset)
    readonly property real maxCascadeX: Math.max(0, (windowCount - 1)) * cascadeOffsetX
    readonly property real maxCascadeY: Math.max(0, (windowCount - 1)) * cascadeOffsetY
    readonly property real thumbnailWidth: Math.max(80, width - windowPadding * 2 - maxCascadeX)
    readonly property real thumbnailHeight: Math.max(60, height - windowPadding * 2 - 24 - maxCascadeY)  // 24 for label

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

        // Workspace label
        Text {
            text: workspaceId
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.margins: 8
            color: OverviewConfig.workspaceNumberColor
            font.bold: isActive
            font.pixelSize: 14
        }
    }

    // Cascading windows within cluster
    Item {
        id: windowContainer
        anchors.fill: parent
        anchors.topMargin: 24  // Below workspace label
        anchors.margins: cluster.windowPadding
        clip: true

        Repeater {
            id: windowRepeater
            model: cluster.windows

            delegate: OverviewWindow {
                id: windowDelegate
                required property var modelData
                required property int index

                // Cascade mode properties
                cascadeMode: true
                cascadeIndex: index

                // Calculate position based on fan state
                cascadeX: cluster.isFanned
                    ? (index % 3) * (cluster.thumbnailWidth * 0.5 + 10)
                    : index * cluster.cascadeOffsetX
                cascadeY: cluster.isFanned
                    ? Math.floor(index / 3) * (cluster.thumbnailHeight * 0.5 + 10)
                    : index * cluster.cascadeOffsetY

                // Thumbnail size
                cascadeWidth: cluster.thumbnailWidth
                cascadeHeight: cluster.thumbnailHeight

                // Window data
                toplevel: modelData
                windowData: {
                    // Get hyprctl client data for this toplevel
                    const address = `0x${modelData.HyprlandToplevel?.address ?? ""}`
                    return HyprlandData.windowByAddress[address] ?? {}
                }
                monitorData: null  // Not used in cascade mode
                widgetMonitor: null  // Not used in cascade mode

                // Animate cascade ↔ fan transitions
                Behavior on cascadeX { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                Behavior on cascadeY { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

                // Click to focus window
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        // Focus window and close overview
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

    // Visual feedback during drag
    scale: isDragging ? 1.02 : 1.0
    Behavior on scale { NumberAnimation { duration: 100 } }

    // Cluster drag area (backing only, windows have their own)
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

        // Configurable modifier+click to fan windows
        onClicked: (mouse) => {
            if (OverviewConfig.isModifierActive("fanReveal", mouse.modifiers)) {
                // Only fan if there are multiple windows to reveal
                if (cluster.windowCount > 1) {
                    cluster.isFanned = !cluster.isFanned
                }
            }
        }
    }
}
