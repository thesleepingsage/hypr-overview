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

    // State
    property bool isDragging: false

    // Windows for this workspace
    property var windows: HyprlandData.toplevelsForWorkspace(workspaceId)
    property int windowCount: windows.length

    // Visual state for drop target
    property bool isDropTarget: false

    // Find window at cluster-local point (called by BoardModeWidget)
    function findWindowAtPoint(localX, localY, excludeAddress) {
        for (var i = windowRepeater.count - 1; i >= 0; i--) {
            const win = windowRepeater.itemAt(i)
            if (!win) continue
            const addr = win.windowData?.address ?? ""
            if (addr === excludeAddress || addr === "") continue
            // Use initX/initY (logical positions) - same as Grid Mode
            if (localX >= win.initX && localX <= win.initX + win.width &&
                localY >= win.initY && localY <= win.initY + win.height) {
                return addr
            }
        }
        return ""
    }

    // ========== FIXED SCALE (like Grid Mode) ==========
    // Get monitor data for this workspace's actual monitor (for correct aspect ratio)
    readonly property var clusterMonitorData: {
        const monitors = HyprlandData.monitors
        if (!monitors || monitors.length === 0) {
            return { width: 1920, height: 1080, x: 0, y: 0, reserved: [0, 0, 0, 0] }
        }

        // Use workspace's monitor (monitorID from hyprctl workspaces -j)
        // This ensures 21:9 ultrawide workspaces get 21:9 clusters, etc.
        const wsMonitorId = workspaceData?.monitorID ?? 0
        const wsMonitor = monitors.find(m => m.id === wsMonitorId)
        return wsMonitor ?? monitors[0]
    }

    // Fixed scale - same as Grid Mode
    readonly property real clusterScale: OverviewConfig.scale

    // Monitor dimensions
    readonly property real monitorWidth: clusterMonitorData.width ?? 1920
    readonly property real monitorHeight: clusterMonitorData.height ?? 1080
    readonly property real reservedLeft: clusterMonitorData.reserved?.[0] ?? 0
    readonly property real reservedTop: clusterMonitorData.reserved?.[1] ?? 0
    readonly property real reservedRight: clusterMonitorData.reserved?.[2] ?? 0
    readonly property real reservedBottom: clusterMonitorData.reserved?.[3] ?? 0

    // Effective monitor size (minus reserved areas like panels)
    readonly property real effectiveWidth: monitorWidth - reservedLeft - reservedRight
    readonly property real effectiveHeight: monitorHeight - reservedTop - reservedBottom

    // Cluster size = effective monitor size * scale (like Grid Mode workspace cells)
    width: effectiveWidth * clusterScale
    height: effectiveHeight * clusterScale

    // Z-order: dragging on top, then active, then by ID
    z: isDragging ? 1000 : (isActive ? 100 : workspaceId)

    // Clipboard-style backing rectangle
    Rectangle {
        id: backing
        anchors.fill: parent
        color: cluster.isDropTarget ? OverviewConfig.workspaceHoverColor : OverviewConfig.workspaceColor
        border.color: cluster.isDropTarget ? OverviewConfig.activeBorderColor :
                      isActive ? OverviewConfig.activeBorderColor : OverviewConfig.workspaceNumberColor
        border.width: cluster.isDropTarget ? 2 : (isActive ? OverviewConfig.activeWorkspaceBorderWidth : 0)
        radius: OverviewConfig.largeRadius
        clip: true  // Clip windows to cluster bounds (like Grid Mode)

        Behavior on color { ColorAnimation { duration: 150 } }

        // DropArea for cross-cluster window moves (mirrors Grid Mode workspace DropArea)
        DropArea {
            id: clusterDropArea
            anchors.fill: parent

            onEntered: {
                const canvas = cluster.parent  // BoardModeWidget
                if (canvas && typeof canvas.draggingFromWorkspace !== 'undefined') {
                    canvas.draggingTargetWorkspace = cluster.workspaceId
                    if (canvas.draggingFromWorkspace !== cluster.workspaceId) {
                        cluster.isDropTarget = true
                    }
                }
            }

            onExited: {
                cluster.isDropTarget = false
                const canvas = cluster.parent
                if (canvas && canvas.draggingTargetWorkspace === cluster.workspaceId) {
                    canvas.draggingTargetWorkspace = -1
                }
            }
        }

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

                    // Window data
                    toplevel: modelData
                    windowData: {
                        const address = `0x${modelData.HyprlandToplevel?.address ?? ""}`
                        return HyprlandData.windowByAddress[address] ?? {}
                    }

                    // === MIRROR GRID MODE POSITIONING ===
                    // NO cascadeMode - use OverviewWindow's built-in initX/initY calculations
                    // This is exactly how Grid Mode does it (OverviewWidget.qml lines 347-358)

                    // Scale - same as Grid Mode
                    scale: OverviewConfig.scale

                    // Monitor data - use window's actual monitor (like Grid Mode lines 344-345)
                    property int winMonitorId: windowData?.monitor ?? 0
                    property var winMonitorData: HyprlandData.monitors.find(m => m.id === winMonitorId) ?? cluster.clusterMonitorData

                    monitorData: winMonitorData
                    // FIX: Use cluster's monitor for widthRatio (like Grid Mode uses panel's monitor)
                    widgetMonitor: cluster.clusterMonitorData

                    // No offset needed - cluster position already places us correctly
                    // (Grid Mode uses offsets to shift windows to their workspace cell,
                    // but in Board Mode each cluster IS the workspace cell)
                    xOffset: 0
                    yOffset: 0

                    // Swap target indicator (when another window is dragged over this one)
                    isSwapTarget: {
                        const canvas = cluster.parent
                        return canvas && canvas.draggingTargetWindowAddress === (windowDelegate.windowData?.address ?? "") &&
                               canvas.draggingWindowAddress !== "" &&
                               canvas.draggingWindowAddress !== (windowDelegate.windowData?.address ?? "")
                    }

                    // Z-order: dragging windows on top
                    z: Drag.active ? 99999 : (windowDelegate.windowData?.floating ? 1 : 0)

                    // Drag support
                    Drag.hotSpot.x: width / 2
                    Drag.hotSpot.y: height / 2

                    // Timer to snap window preview back to its calculated position
                    Timer {
                        id: snapBackTimer
                        interval: 50
                        repeat: false
                        onTriggered: {
                            windowDelegate.x = windowDelegate.initX
                            windowDelegate.y = windowDelegate.initY
                        }
                    }

                    // Full drag MouseArea (mirrors Grid Mode OverviewWidget.qml:383-449)
                    MouseArea {
                        id: dragArea
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                        drag.target: parent

                        onEntered: windowDelegate.hovered = true
                        onExited: windowDelegate.hovered = false

                        onPressed: (mouse) => {
                            const canvas = cluster.parent  // BoardModeWidget
                            if (!canvas) return

                            canvas.draggingFromWorkspace = cluster.workspaceId
                            canvas.draggingWindowAddress = windowDelegate.windowData?.address ?? ""
                            windowDelegate.pressed = true
                            windowDelegate.Drag.active = true
                            windowDelegate.Drag.source = windowDelegate
                            windowDelegate.Drag.hotSpot.x = mouse.x
                            windowDelegate.Drag.hotSpot.y = mouse.y
                        }

                        onPositionChanged: (mouse) => {
                            if (!windowDelegate.Drag.active) return
                            // Skip swap detection for floating windows
                            if (windowDelegate.windowData?.floating) return

                            const canvas = cluster.parent
                            if (!canvas) return

                            // Map to canvas (BoardModeWidget) coordinates for cross-cluster detection
                            const globalPos = windowDelegate.mapToItem(canvas, mouse.x, mouse.y)
                            canvas.draggingTargetWindowAddress = canvas.findWindowAtPoint(
                                globalPos.x, globalPos.y,
                                windowDelegate.windowData?.address ?? ""
                            )
                        }

                        onReleased: {
                            const canvas = cluster.parent
                            if (!canvas) {
                                windowDelegate.pressed = false
                                windowDelegate.Drag.active = false
                                snapBackTimer.restart()
                                return
                            }

                            // Capture drag state before reset
                            const targetWs = canvas.draggingTargetWorkspace
                            const targetWindow = canvas.draggingTargetWindowAddress
                            const sourceWs = canvas.draggingFromWorkspace
                            const currentWs = cluster.workspaceId
                            const isFloating = windowDelegate.windowData?.floating ?? false
                            const windowAddress = windowDelegate.windowData?.address ?? ""

                            // Reset drag state
                            windowDelegate.pressed = false
                            windowDelegate.Drag.active = false
                            canvas.draggingFromWorkspace = -1
                            canvas.draggingWindowAddress = ""
                            canvas.draggingTargetWindowAddress = ""
                            cluster.isDropTarget = false

                            // PRIORITY 1: Tiled window swap (same workspace, over another window)
                            if (targetWindow !== "" && !isFloating) {
                                if (sourceWs === targetWs || targetWs === -1 || targetWs === currentWs) {
                                    canvas.handleWindowSwap(windowAddress, targetWindow, () => snapBackTimer.restart())
                                    return
                                }
                            }

                            // PRIORITY 2: Tiled window cross-workspace move
                            if (!isFloating && targetWs !== -1 && targetWs !== currentWs) {
                                canvas.handleWindowMove(windowAddress, targetWs, currentWs, () => snapBackTimer.restart())
                                return
                            }

                            // Default: Snap back to original position
                            snapBackTimer.restart()
                        }

                        onClicked: {
                            // Only handle click if not dragging
                            if (windowDelegate.Drag.active) return

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
