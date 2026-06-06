import QtQuick
import QtQuick.Shapes
import Quickshell.Hyprland

Item {
    id: cluster

    // Required properties
    required property int workspaceId
    required property var workspaceData
    required property bool isActive

    // Canvas dimensions for percentage-based positioning (resolution-independent)
    readonly property real canvasWidth: parent?.width ?? 1920
    readonly property real canvasHeight: parent?.height ?? 1080

    // Position management - use state position, but allow drag to override
    property point statePosition: ClusterPositionState.getPosition(workspaceId, canvasWidth, canvasHeight)

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

    // Track if any window inside this cluster is being dragged (for z-order boost)
    property bool hasWindowDragging: false

    // Container padding for "picture frame" effect (uniform spacing on all sides)
    readonly property real containerPadding: 3

    // Header tab configuration
    readonly property real headerHeight: 22
    readonly property real headerPadding: 10  // Horizontal padding inside tab
    readonly property real headerArcWidth: 14  // Width of the curved right edge
    readonly property real headerMinWidth: 40
    readonly property real headerMaxWidth: width  // Can extend to full cluster width

    // Foot extends down just enough to cover the corner gap (containerPadding only)
    readonly property real headerFootHeight: containerPadding
    readonly property real headerFootWidth: containerPadding

    // Computed header text for display
    readonly property string headerDisplayText: {
        const id = workspaceId
        // Strip surrounding quotes from workspace name (Hyprland includes literal quotes)
        let name = workspaceData?.name ?? ""
        if (name.startsWith('"') && name.endsWith('"')) {
            name = name.slice(1, -1)
        }
        const hasCustomName = name !== "" && name !== String(id)
        return hasCustomName ? `${id} - ${name}` : String(id)
    }

    // Find window at cluster-local point (called by BoardModeWidget)
    function findWindowAtPoint(localX, localY, excludeAddress) {
        // Account for window padding offset and header height
        const adjustedX = localX - containerPadding
        const adjustedY = localY - containerPadding - headerHeight

        for (var i = windowRepeater.count - 1; i >= 0; i--) {
            const win = windowRepeater.itemAt(i)
            if (!win) continue
            const addr = win.windowData?.address ?? ""
            if (addr === excludeAddress || addr === "") continue
            // Use initX/initY (logical positions) - same as Grid Mode
            if (adjustedX >= win.initX && adjustedX <= win.initX + win.width &&
                adjustedY >= win.initY && adjustedY <= win.initY + win.height) {
                return addr
            }
        }
        return ""
    }

    // ========== BOARD MODE SCALE ==========
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

    // Board mode scale from config (separate from grid mode scale)
    readonly property real clusterScale: OverviewConfig.boardMode.scale

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

    // Cluster size = effective monitor size * scale, minus padding for "picture frame" effect
    width: effectiveWidth * clusterScale + containerPadding * 2
    height: effectiveHeight * clusterScale + containerPadding * 2 + headerHeight

    // Z-order: dragging on top, then active, then by ID
    z: hasWindowDragging ? 100000 : (isDragging ? 1000 : (isActive ? 100 : workspaceId))

    // Header tab with curved right edge (folder tab style) + foot extension
    Item {
        id: headerTab
        anchors.top: parent.top
        anchors.left: parent.left
        height: cluster.headerHeight + cluster.headerFootHeight  // Includes foot
        z: 100

        // Dynamic width based on text content
        width: Math.min(
            cluster.headerMaxWidth,
            Math.max(cluster.headerMinWidth, headerText.implicitWidth + cluster.headerPadding * 2 + cluster.headerArcWidth)
        )

        Shape {
            anchors.fill: parent
            layer.enabled: true
            layer.smooth: true

            ShapePath {
                fillColor: cluster.isDropTarget ? OverviewConfig.workspaceHoverColor : OverviewConfig.workspaceColor
                strokeWidth: 0

                // Start at bottom of foot (left edge)
                startX: 0
                startY: cluster.headerHeight + cluster.headerFootHeight

                // Up the full left edge
                PathLine { x: 0; y: OverviewConfig.smallRadius }

                // TL corner - CW for convex outward curve
                PathArc {
                    x: OverviewConfig.smallRadius
                    y: 0
                    radiusX: OverviewConfig.smallRadius
                    radiusY: OverviewConfig.smallRadius
                    direction: PathArc.Clockwise
                }

                // Across the top to arc start
                PathLine { x: headerTab.width - cluster.headerArcWidth; y: 0 }

                // Curved right edge (swooping down to main tab bottom)
                PathQuad {
                    x: headerTab.width
                    y: cluster.headerHeight
                    controlX: headerTab.width
                    controlY: 0
                }

                // Across bottom to foot inside corner
                PathLine { x: cluster.headerFootWidth; y: cluster.headerHeight }

                // Inside corner of foot - small curve to fill the corner gap
                PathArc {
                    x: 0
                    y: cluster.headerHeight + cluster.headerFootHeight
                    radiusX: cluster.containerPadding
                    radiusY: cluster.containerPadding
                    direction: PathArc.Clockwise
                }

                // Path closes back to start
            }
        }

        // Text label (centered in main tab body, not the foot)
        Text {
            id: headerText
            anchors.left: parent.left
            anchors.leftMargin: cluster.headerPadding
            y: (cluster.headerHeight - implicitHeight) / 2

            text: cluster.headerDisplayText

            color: OverviewConfig.workspaceNumberColor
            font.bold: cluster.isActive
            font.pixelSize: 13
        }
    }

    // Active workspace highlight overlay - MUST be sibling of headerTab for proper z-ordering
    // Covers the backing area (window content), renders above everything including the tab foot
    Rectangle {
        id: activeHighlight
        anchors.fill: parent
        anchors.topMargin: cluster.headerHeight  // Match backing position
        color: "transparent"
        border.width: isActive ? OverviewConfig.activeWorkspaceBorderWidth : 0
        border.color: OverviewConfig.activeBorderColor
        radius: OverviewConfig.smallRadius
        z: 200  // Above headerTab (z: 100)
    }

    // Clipboard-style backing rectangle (below header tab)
    Rectangle {
        id: backing
        anchors.fill: parent
        anchors.topMargin: cluster.headerHeight  // Start below header tab
        color: cluster.isDropTarget ? OverviewConfig.workspaceHoverColor : OverviewConfig.workspaceColor
        // Border for drop target only - active highlight is a separate overlay (like Grid Mode)
        border.color: cluster.isDropTarget ? OverviewConfig.workspaceHoverColor : "transparent"
        border.width: cluster.isDropTarget ? 2 : 0
        radius: OverviewConfig.smallRadius
        // NO clip: true - windowSpace uses margins to keep windows away from rounded corners

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

        // Windows container - padding handled via window x/y offset (not margins)
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
                        const address = HyprlandData.normalizeAddr(modelData.address)
                        return HyprlandData.windowByAddress[address] ?? {}
                    }

                    // Direct address property (mirrors Grid Mode OverviewWidget.qml:342)
                    property string address: HyprlandData.normalizeAddr(modelData.address)
                    property var stableId: windowData?.stableId

                    // === MIRROR GRID MODE POSITIONING ===
                    // NO cascadeMode - use OverviewWindow's built-in initX/initY calculations
                    // This is exactly how Grid Mode does it (OverviewWidget.qml lines 347-358)

                    // Scale - uses board mode scale for consistency
                    scale: OverviewConfig.boardMode.scale

                    // Monitor data - use window's actual monitor (like Grid Mode lines 344-345)
                    property int winMonitorId: windowData?.monitor ?? 0
                    property var winMonitorData: HyprlandData.monitors.find(m => m.id === winMonitorId) ?? cluster.clusterMonitorData

                    monitorData: winMonitorData
                    // FIX: Use cluster's monitor for widthRatio (like Grid Mode uses panel's monitor)
                    widgetMonitor: cluster.clusterMonitorData

                    // Padding offset for "picture frame" effect
                    x: initX + cluster.containerPadding
                    y: initY + cluster.containerPadding

                    // No additional offset needed in initX/initY calculation
                    xOffset: 0
                    yOffset: 0

                    // Pass cluster background color for corner masks
                    containerColor: backing.color

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
                            windowDelegate.x = windowDelegate.initX + cluster.containerPadding
                            windowDelegate.y = windowDelegate.initY + cluster.containerPadding
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
                            // If cluster drag modifier is pressed (without stash modifier), reject for cluster drag
                            // But if stash modifier is also held, keep the event for stash operations
                            const isClusterDrag = OverviewConfig.isModifierActive("clusterDrag", mouse.modifiers)
                            const isStashOp = StashState.isModifierHeld(mouse.modifiers)
                            if (isClusterDrag && !isStashOp) {
                                mouse.accepted = false
                                return
                            }

                            const canvas = cluster.parent  // BoardModeWidget
                            if (!canvas) return

                            canvas.draggingFromWorkspace = cluster.workspaceId
                            canvas.draggingWindowAddress = windowDelegate.address
                            canvas.draggingWindowStableId = windowDelegate.stableId ?? null
                            windowDelegate.pressed = true
                            windowDelegate.Drag.active = true
                            windowDelegate.Drag.source = windowDelegate
                            windowDelegate.Drag.hotSpot.x = mouse.x
                            windowDelegate.Drag.hotSpot.y = mouse.y
                            cluster.hasWindowDragging = true  // Boost cluster z-order
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

                            // PRIORITY 0: Stash drop (check first, before any other logic)
                            if (StashState.draggingTargetStash !== "") {
                                const trayName = StashState.draggingTargetStash;
                                StashState.draggingTargetStash = "";
                                windowDelegate.stashWindow(trayName);
                                windowDelegate.pressed = false;
                                windowDelegate.Drag.active = false;
                                cluster.hasWindowDragging = false;
                                if (canvas) {
                                    canvas.draggingFromWorkspace = -1;
                                    canvas.draggingWindowAddress = "";
                                    canvas.draggingWindowStableId = null;
                                    canvas.draggingTargetWindowAddress = "";
                                }
                                return;
                            }

                            if (!canvas) {
                                console.log(`[Board Swap] No canvas - early return`)
                                windowDelegate.pressed = false
                                windowDelegate.Drag.active = false
                                cluster.hasWindowDragging = false
                                snapBackTimer.restart()
                                return
                            }

                            // Capture drag state before reset
                            const targetWs = canvas.draggingTargetWorkspace
                            const targetWindow = canvas.draggingTargetWindowAddress
                            const sourceWs = canvas.draggingFromWorkspace
                            const currentWs = cluster.workspaceId
                            const isFloating = windowDelegate.windowData?.floating ?? false
                            const windowAddress = canvas.draggingWindowAddress  // Use captured address from press time

                            console.log(`[Board Swap Debug] sourceWs=${sourceWs} targetWs=${targetWs} currentWs=${currentWs}`)
                            console.log(`[Board Swap Debug] targetWindow="${targetWindow}" windowAddress="${windowAddress}" isFloating=${isFloating}`)

                            // Reset drag state
                            windowDelegate.pressed = false
                            windowDelegate.Drag.active = false
                            canvas.draggingFromWorkspace = -1
                            canvas.draggingWindowAddress = ""
                            canvas.draggingWindowStableId = null
                            canvas.draggingTargetWindowAddress = ""
                            cluster.isDropTarget = false
                            cluster.hasWindowDragging = false  // Clear z-boost

                            // PRIORITY 1: Tiled window swap (same workspace, over another window)
                            if (targetWindow !== "" && !isFloating) {
                                console.log(`[Board Swap] Condition 1,2 PASS`)
                                if (sourceWs === targetWs || targetWs === -1 || targetWs === currentWs) {
                                    console.log(`[Board Swap] Condition 3 PASS - executing swap`)
                                    canvas.handleWindowSwap(windowAddress, targetWindow, () => snapBackTimer.restart())
                                    return
                                } else {
                                    console.log(`[Board Swap] Condition 3 FAIL: sourceWs=${sourceWs} targetWs=${targetWs} currentWs=${currentWs}`)
                                }
                            } else {
                                console.log(`[Board Swap] Condition 1,2 FAIL: targetWindow="${targetWindow}" isFloating=${isFloating}`)
                            }

                            // PRIORITY 2: Floating window actions (cross-ws move OR same-ws reposition)
                            if (isFloating) {
                                // Calculate cluster-relative position (remove container padding)
                                const clusterRelX = windowDelegate.x - cluster.containerPadding
                                const clusterRelY = windowDelegate.y - cluster.containerPadding
                                canvas.handleFloatingWindowAction(
                                    windowAddress,
                                    clusterRelX,
                                    clusterRelY,
                                    windowDelegate.windowData,
                                    cluster.clusterMonitorData,
                                    targetWs,
                                    currentWs,
                                    () => snapBackTimer.restart()
                                )
                                return
                            }

                            // PRIORITY 3: Tiled window cross-workspace move
                            if (targetWs !== -1 && targetWs !== currentWs) {
                                canvas.handleWindowMove(windowAddress, targetWs, currentWs, () => snapBackTimer.restart())
                                return
                            }

                            // Default: Snap back to original position
                            snapBackTimer.restart()
                        }

                        onClicked: (event) => {
                            // Only handle click if not dragging
                            if (windowDelegate.Drag.active) return;
                            if (!windowDelegate.windowData) return;

                            if (event.button === Qt.MiddleButton) {
                                // Middle click: close window
                                Hyprland.dispatch(`closewindow address:${windowDelegate.address}`);
                                event.accepted = true;
                            } else if (event.button === Qt.LeftButton) {
                                // Check modifiers for stash operations (mirrors Grid Mode)
                                const primaryHeld = StashState.isModifierHeld(event.modifiers);
                                const secondaryHeld = StashState.isSecondaryModifierHeld(event.modifiers);

                                if (primaryHeld && secondaryHeld) {
                                    // Primary+Secondary modifier: stash to secondary tray
                                    const secondaryTray = StashState.trays[1]?.name ?? "later";
                                    windowDelegate.stashWindow(secondaryTray);
                                    event.accepted = true;
                                } else if (primaryHeld) {
                                    // Primary modifier only: stash to primary tray
                                    const primaryTray = StashState.trays[0]?.name ?? "quick";
                                    windowDelegate.stashWindow(primaryTray);
                                    event.accepted = true;
                                } else {
                                    // Regular left click: focus window and close overview
                                    OverviewState.close();
                                    Hyprland.dispatch(`focuswindow address:${windowDelegate.address}`);
                                    event.accepted = true;
                                }
                            }
                        }
                    }
                }
            }
        }

        // Cluster drag area - z: -1 puts it BEHIND windowSpace
        // Windows receive events first; if they reject (modifier pressed), this catches it
        MouseArea {
            id: clusterDragArea
            anchors.fill: parent
            z: -1  // BEHIND windowSpace so windows receive events first
            drag.target: null  // Set dynamically when handling cluster drag

            onPressed: (mouse) => {
                // Only reaches here if window MouseArea rejected the event (modifier pressed)
                clusterDragArea.drag.target = cluster
                cluster.isDragging = true
            }

            onPositionChanged: {
                // Real-time clamping during drag (vapor barrier collision)
                if (cluster.isDragging) {
                    // Basic screen bounds
                    cluster.x = Math.max(0, Math.min(cluster.canvasWidth - cluster.width, cluster.x))
                    cluster.y = Math.max(0, Math.min(cluster.canvasHeight - cluster.height, cluster.y))

                    // Vapor barrier collision with stash tray
                    const clamped = ClusterPositionState.clampToAvoidTray(
                        cluster.x, cluster.y, cluster.width, cluster.height)
                    cluster.x = clamped.x
                    cluster.y = clamped.y
                }
            }

            onReleased: {
                if (cluster.isDragging) {
                    // Final position is already clamped from onPositionChanged
                    ClusterPositionState.setPosition(workspaceId, cluster.x, cluster.y, cluster.canvasWidth, cluster.canvasHeight)
                    cluster.isDragging = false
                    clusterDragArea.drag.target = null
                }
            }
        }
    }

    // Visual feedback during drag
    scale: isDragging ? 1.02 : 1.0
    Behavior on scale { NumberAnimation { duration: 100 } }
}
