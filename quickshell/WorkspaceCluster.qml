import QtQuick

Item {
    id: cluster

    // Required properties
    required property int workspaceId
    required property var workspaceData
    required property bool isActive

    // Position from ClusterPositionState
    x: ClusterPositionState.getPosition(workspaceId).x
    y: ClusterPositionState.getPosition(workspaceId).y

    // Sizing from config
    width: OverviewConfig.boardMode.clusterWidth
    height: OverviewConfig.boardMode.clusterHeight

    // State
    property bool isDragging: false
    property bool isFanned: false

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

    // TODO: T4 - Add window Repeater for cascading windows
    // Windows will be rendered inside the cluster with cascade offsets

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
                // Only fan if there are windows to reveal
                // TODO: T6 - Enable fan when window Repeater is added
                // if (windows.length > 1) {
                //     isFanned = !isFanned
                // }
            }
        }
    }
}
