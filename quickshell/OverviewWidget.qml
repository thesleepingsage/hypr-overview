pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "." as Local

/**
 * OverviewWidget - Main workspace grid component
 * Displays a grid of workspaces with live window previews
 * Adapted from end-4/dots-hyprland for hypr-overview
 */
Item {
    id: root

    // Required: panel window reference for monitor access
    required property var panelWindow

    // Monitor info
    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(panelWindow.screen)
    readonly property var monitorData: HyprlandData.monitors.find(m => m.id === root.monitor?.id)

    // Config
    readonly property int rows: OverviewConfig.rows
    readonly property int columns: OverviewConfig.columns
    readonly property real scale: OverviewConfig.scale
    readonly property bool orderRightLeft: OverviewConfig.orderRightLeft
    readonly property bool orderBottomUp: OverviewConfig.orderBottomUp
    readonly property bool showWorkspaceNumbers: OverviewConfig.showWorkspaceNumbers

    // Computed properties
    readonly property int workspacesShown: rows * columns
    readonly property int workspaceGroup: Math.floor((monitor.activeWorkspace?.id - 1) / workspacesShown)

    // Window data from HyprlandData
    property var windowByAddress: HyprlandData.windowByAddress

    // Visual properties
    property real workspaceImplicitWidth: {
        const monWidth = monitorData?.width ?? monitor?.width ?? 1920;
        const reserved = (monitorData?.reserved?.[0] ?? 0) + (monitorData?.reserved?.[2] ?? 0);
        return (monWidth - reserved) * scale;
    }
    property real workspaceImplicitHeight: {
        const monHeight = monitorData?.height ?? monitor?.height ?? 1080;
        const reserved = (monitorData?.reserved?.[1] ?? 0) + (monitorData?.reserved?.[3] ?? 0);
        return (monHeight - reserved) * scale;
    }

    // Visual properties from config (now user-customizable)
    property real largeRadius: OverviewConfig.largeRadius
    property real smallRadius: OverviewConfig.smallRadius
    property real workspaceSpacing: OverviewConfig.workspaceSpacing
    property real padding: OverviewConfig.gridPadding

    property color backgroundColor: OverviewConfig.backgroundColor
    property color workspaceColor: OverviewConfig.workspaceColor
    property color workspaceHoverColor: OverviewConfig.workspaceHoverColor
    property color activeBorderColor: OverviewConfig.activeBorderColor
    property color workspaceNumberColor: OverviewConfig.workspaceNumberColor

    // Drag state
    property int draggingFromWorkspace: -1
    property int draggingTargetWorkspace: -1
    property string draggingWindowAddress: ""
    property string draggingTargetWindowAddress: ""

    // Size
    implicitWidth: overviewBackground.implicitWidth
    implicitHeight: overviewBackground.implicitHeight

    // Helper functions for workspace layout
    function getWsRow(ws) {
        var normalRow = Math.floor((ws - 1) / columns) % rows;
        return orderBottomUp ? rows - normalRow - 1 : normalRow;
    }

    function getWsColumn(ws) {
        var normalCol = (ws - 1) % columns;
        return orderRightLeft ? columns - normalCol - 1 : normalCol;
    }

    function getWsInCell(ri, ci) {
        var actualRow = orderBottomUp ? rows - ri - 1 : ri;
        var actualCol = orderRightLeft ? columns - ci - 1 : ci;
        return actualRow * columns + actualCol + 1;
    }

    // Calculate which workspace a point belongs to based on grid position
    function getWorkspaceAtPosition(x, y) {
        const wsWidth = root.workspaceImplicitWidth + workspaceSpacing;
        const wsHeight = root.workspaceImplicitHeight + workspaceSpacing;
        const col = Math.floor(x / wsWidth);
        const row = Math.floor(y / wsHeight);
        if (col < 0 || col >= root.columns || row < 0 || row >= root.rows) return -1;
        // Use getWsInCell to handle orderRightLeft/orderBottomUp correctly
        return getWsInCell(row, col);
    }

    // Find window at point (for swap detection)
    function findWindowAtPoint(globalX, globalY, excludeAddress) {
        for (var i = 0; i < windowRepeater.count; i++) {
            var win = windowRepeater.itemAt(i)
            if (!win) continue;
            if (win.address === excludeAddress) continue
            // Use initX/initY (logical positions from HyprlandData) instead of x/y (visual positions)
            // Visual positions can be stale after drag breaks the binding
            if (globalX >= win.initX && globalX <= win.initX + win.width &&
                globalY >= win.initY && globalY <= win.initY + win.height) {
                return win.address
            }
        }
        return ""
    }

    // Find window delegate by address (for getting target window's workspace)
    function findWindowByAddress(address) {
        for (var i = 0; i < windowRepeater.count; i++) {
            var win = windowRepeater.itemAt(i);
            if (win && win.address === address) return win;
        }
        return null;
    }

    // --- Drag Action Handlers (extracted from onReleased for clarity) ---

    /**
     * Handle window swap between two tiled windows
     * @returns true if swap was executed
     */
    function handleWindowSwap(windowDelegate, targetWindow, snapBackTimer) {
        const swapCmd = Local.Config.useHy3
            ? `hy3:swapwindow address:${windowDelegate.address}, address:${targetWindow}`
            : `swapwindow address:${targetWindow}`;
        console.log(`[hypr-overview] SWAP: ${swapCmd}`);
        Hyprland.dispatch(swapCmd);

        // Wait for HyprlandData to refresh, then snap to updated positions
        function onDataUpdated() {
            HyprlandData.windowListUpdated.disconnect(onDataUpdated);
            snapBackTimer.restart();
        }
        HyprlandData.windowListUpdated.connect(onDataUpdated);
        HyprlandData.updateWindowList();
        return true;
    }

    /**
     * Handle floating window move or reposition
     * @returns true if action was executed
     */
    function handleFloatingWindowAction(windowDelegate, targetWs, sourceWs) {
        if (targetWs !== -1 && targetWs !== sourceWs) {
            // Cross-workspace move
            console.log(`[hypr-overview] FLOAT MOVE: ws ${sourceWs} -> ${targetWs}`);
            Hyprland.dispatch(`movetoworkspacesilent ${targetWs}, address:${windowDelegate.winData?.address}`);
        } else {
            // Same-ws reposition - use absolute pixel coordinates
            const posInWorkspaceX = windowDelegate.x - windowDelegate.xOffset;
            const posInWorkspaceY = windowDelegate.y - windowDelegate.yOffset;
            const posOnMonitorX = posInWorkspaceX / (windowDelegate.widthRatio * windowDelegate.scale);
            const posOnMonitorY = posInWorkspaceY / (windowDelegate.heightRatio * windowDelegate.scale);
            const monitorX = windowDelegate.winMonitorData?.x ?? 0;
            const monitorY = windowDelegate.winMonitorData?.y ?? 0;
            const absoluteX = Math.round(monitorX + posOnMonitorX);
            const absoluteY = Math.round(monitorY + posOnMonitorY);
            console.log(`[hypr-overview] FLOAT REPOSITION: ${absoluteX}, ${absoluteY}`);
            Hyprland.dispatch(`movewindowpixel exact ${absoluteX} ${absoluteY}, address:${windowDelegate.winData?.address}`);
        }
        return true;
    }

    /**
     * Handle tiled window move to different workspace
     * @returns true if move was executed
     */
    function handleTiledWindowMove(windowDelegate, targetWs, currentWs, snapBackTimer) {
        if (targetWs === -1 || targetWs === currentWs) return false;

        console.log(`[hypr-overview] MOVE: ws ${currentWs} -> ${targetWs}`);
        Hyprland.dispatch(`movetoworkspacesilent ${targetWs}, address:${windowDelegate.winData?.address}`);

        // Wait for HyprlandData to refresh, then snap to correct position
        function onMoveDataUpdated() {
            HyprlandData.windowListUpdated.disconnect(onMoveDataUpdated);
            snapBackTimer.restart();
        }
        HyprlandData.windowListUpdated.connect(onMoveDataUpdated);
        HyprlandData.updateWindowList();
        return true;
    }

    // Background
    Rectangle {
        id: overviewBackground
        anchors.fill: parent

        implicitWidth: mainLayout.implicitWidth + padding * 2
        implicitHeight: mainLayout.implicitHeight + padding * 2
        radius: largeRadius + padding
        color: backgroundColor

        // Main layout (workspace grid + stash trays)
        Column {
            id: mainLayout
            anchors.centerIn: parent
            spacing: 12

            // Workspace grid
            Column {
                id: workspaceColumnLayout
                spacing: workspaceSpacing

            Repeater {
                model: root.rows

                delegate: Row {
                    id: rowDelegate
                    required property int index
                    spacing: workspaceSpacing

                    Repeater {
                        model: root.columns

                        delegate: Rectangle {
                            id: workspace
                            required property int index

                            property int colIndex: index
                            property int rowIndex: rowDelegate.index
                            property int workspaceValue: root.workspaceGroup * root.workspacesShown + getWsInCell(rowIndex, colIndex)
                            property bool hoveredWhileDragging: false

                            implicitWidth: root.workspaceImplicitWidth
                            implicitHeight: root.workspaceImplicitHeight
                            color: hoveredWhileDragging ? workspaceHoverColor : workspaceColor

                            // Corner radius based on position in grid
                            property bool atLeft: colIndex === 0
                            property bool atRight: colIndex === root.columns - 1
                            property bool atTop: rowIndex === 0
                            property bool atBottom: rowIndex === root.rows - 1

                            topLeftRadius: (atLeft && atTop) ? largeRadius : smallRadius
                            topRightRadius: (atRight && atTop) ? largeRadius : smallRadius
                            bottomLeftRadius: (atLeft && atBottom) ? largeRadius : smallRadius
                            bottomRightRadius: (atRight && atBottom) ? largeRadius : smallRadius

                            border.width: hoveredWhileDragging ? 2 : 0
                            border.color: workspaceHoverColor

                            // Workspace number
                            Text {
                                visible: root.showWorkspaceNumbers
                                anchors.centerIn: parent
                                text: workspace.workspaceValue
                                font.pixelSize: Math.min(workspace.width, workspace.height) * 0.4
                                font.weight: Font.DemiBold
                                color: workspaceNumberColor
                            }

                            // Click to switch workspace
                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.LeftButton
                                onPressed: {
                                    if (root.draggingTargetWorkspace === -1) {
                                        OverviewState.close();
                                        Hyprland.dispatch(`workspace ${workspace.workspaceValue}`);
                                    }
                                }
                            }

                            // Drop area for window dragging
                            DropArea {
                                anchors.fill: parent
                                onEntered: {
                                    root.draggingTargetWorkspace = workspace.workspaceValue;
                                    if (root.draggingFromWorkspace !== root.draggingTargetWorkspace) {
                                        workspace.hoveredWhileDragging = true;
                                    }
                                }
                                onExited: {
                                    workspace.hoveredWhileDragging = false;
                                    if (root.draggingTargetWorkspace === workspace.workspaceValue) {
                                        root.draggingTargetWorkspace = -1;
                                    }
                                }
                            }
                        }
                    }
                }
            }
            } // end workspaceColumnLayout

            // Stash tray container
            StashTrayContainer {
                id: stashTrayContainer
                monitorData: root.monitorData
                widgetMonitor: root.monitorData
            }
        } // end mainLayout

        // Windows layer (on top of workspace backgrounds)
        Item {
            id: windowSpace
            // Position to overlay on workspace grid, not entire layout
            x: mainLayout.x
            y: mainLayout.y
            width: workspaceColumnLayout.implicitWidth
            height: workspaceColumnLayout.implicitHeight

            // Window repeater
            Repeater {
                id: windowRepeater
                model: ScriptModel {
                    values: {
                        const toplevels = ToplevelManager.toplevels.values;

                        // Filter toplevels to only show windows in current workspace group
                        return toplevels.filter((toplevel) => {
                            const rawAddress = toplevel.HyprlandToplevel?.address;
                            // HyprlandToplevel.address does NOT include 0x prefix, but hyprctl does
                            const address = `0x${rawAddress}`;
                            var win = root.windowByAddress[address];

                            if (!win?.workspace?.id) return false;
                            const wsId = win.workspace.id;
                            const inGroup = (root.workspaceGroup * root.workspacesShown < wsId &&
                                           wsId <= (root.workspaceGroup + 1) * root.workspacesShown);
                            return inGroup;
                        });
                    }
                }

                delegate: OverviewWindow {
                    id: windowDelegate
                    required property var modelData

                    property var address: `0x${modelData.HyprlandToplevel?.address}`
                    property var winData: root.windowByAddress[address]
                    property int winMonitorId: winData?.monitor ?? -1
                    property var winMonitorData: HyprlandData.monitors.find(m => m.id === winMonitorId)

                    // OverviewWindow properties
                    toplevel: modelData
                    windowData: winData
                    monitorData: winMonitorData
                    scale: root.scale
                    widgetMonitor: root.monitorData

                    // Workspace position offset
                    property int wsColIndex: getWsColumn(winData?.workspace?.id ?? 1)
                    property int wsRowIndex: getWsRow(winData?.workspace?.id ?? 1)
                    xOffset: (root.workspaceImplicitWidth + workspaceSpacing) * wsColIndex
                    yOffset: (root.workspaceImplicitHeight + workspaceSpacing) * wsRowIndex

                    // Swap target indicator
                    isSwapTarget: root.draggingTargetWindowAddress === address &&
                                  root.draggingWindowAddress !== "" &&
                                  root.draggingWindowAddress !== address

                    // Z-order: dragging windows on top
                    z: Drag.active ? 99999 : (1 + (winData?.floating ?? 0))

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

                    MouseArea {
                        id: dragArea
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                        drag.target: parent

                        onEntered: windowDelegate.hovered = true
                        onExited: windowDelegate.hovered = false

                        onPressed: (mouse) => {
                            root.draggingFromWorkspace = windowDelegate.winData?.workspace?.id ?? -1;
                            root.draggingWindowAddress = windowDelegate.address;
                            windowDelegate.pressed = true;
                            windowDelegate.Drag.active = true;
                            windowDelegate.Drag.source = windowDelegate;
                            windowDelegate.Drag.hotSpot.x = mouse.x;
                            windowDelegate.Drag.hotSpot.y = mouse.y;
                        }

                        onPositionChanged: (mouse) => {
                            if (!windowDelegate.Drag.active) return;
                            // Floating windows don't participate in swap logic - skip target detection
                            if (windowDelegate.winData?.floating) return;
                            var pos = windowDelegate.mapToItem(windowSpace, mouse.x, mouse.y);
                            root.draggingTargetWindowAddress = findWindowAtPoint(pos.x, pos.y, windowDelegate.address);
                        }

                        onReleased: {
                            // Capture drag state before reset
                            const targetWs = root.draggingTargetWorkspace;
                            const targetWindow = root.draggingTargetWindowAddress;
                            const sourceWs = root.draggingFromWorkspace;
                            const currentWsFromData = windowDelegate.winData?.workspace?.id ?? -1;
                            const currentWsFromPosition = root.getWorkspaceAtPosition(windowDelegate.initX, windowDelegate.initY);
                            const currentWs = currentWsFromPosition !== -1 ? currentWsFromPosition : currentWsFromData;
                            const isFloating = windowDelegate.winData?.floating ?? false;

                            // Reset drag state
                            windowDelegate.pressed = false;
                            windowDelegate.Drag.active = false;
                            root.draggingFromWorkspace = -1;
                            root.draggingWindowAddress = "";
                            root.draggingTargetWindowAddress = "";

                            // PRIORITY 1: Tiled window swap (same workspace, over another window)
                            if (targetWindow !== "" && !isFloating) {
                                if (sourceWs === targetWs || targetWs === -1) {
                                    root.handleWindowSwap(windowDelegate, targetWindow, snapBackTimer);
                                    return;
                                }
                            }

                            // PRIORITY 2: Floating window actions
                            if (isFloating) {
                                root.handleFloatingWindowAction(windowDelegate, targetWs, sourceWs);
                                return;
                            }

                            // PRIORITY 3: Tiled window cross-workspace move
                            if (root.handleTiledWindowMove(windowDelegate, targetWs, currentWs, snapBackTimer)) {
                                return;
                            }

                            // Default: Snap back to original position
                            snapBackTimer.restart();
                        }

                        onClicked: (event) => {
                            if (!windowDelegate.winData) return;

                            if (event.button === Qt.MiddleButton) {
                                // Middle click: close window
                                Hyprland.dispatch(`closewindow address:${windowDelegate.winData.address}`);
                                event.accepted = true;
                            } else if (event.button === Qt.LeftButton) {
                                // Check modifiers for stash operations (uses configured keys from StashState)
                                const primaryHeld = StashState.isModifierHeld(event.modifiers);
                                const secondaryHeld = StashState.isSecondaryModifierHeld(event.modifiers);

                                if (primaryHeld && secondaryHeld) {
                                    // Primary+Secondary modifier: stash to secondary tray
                                    windowDelegate.stashWindow("later");
                                    event.accepted = true;
                                } else if (primaryHeld) {
                                    // Primary modifier only: stash to quick tray
                                    windowDelegate.stashWindow("quick");
                                    event.accepted = true;
                                } else {
                                    // Regular left click: focus window
                                    OverviewState.close();
                                    Hyprland.dispatch(`focuswindow address:${windowDelegate.winData.address}`);
                                    event.accepted = true;
                                }
                            }
                        }
                    }
                }
            }

            // Active workspace indicator
            Rectangle {
                id: focusedWorkspaceIndicator
                property int rowIndex: getWsRow(root.monitor.activeWorkspace?.id ?? 1)
                property int colIndex: getWsColumn(root.monitor.activeWorkspace?.id ?? 1)

                x: (root.workspaceImplicitWidth + workspaceSpacing) * colIndex
                y: (root.workspaceImplicitHeight + workspaceSpacing) * rowIndex
                width: root.workspaceImplicitWidth
                height: root.workspaceImplicitHeight

                color: "transparent"
                border.width: OverviewConfig.activeWorkspaceBorderWidth
                border.color: activeBorderColor

                // Corner radius matching workspace position
                property bool atLeft: colIndex === 0
                property bool atRight: colIndex === root.columns - 1
                property bool atTop: rowIndex === 0
                property bool atBottom: rowIndex === root.rows - 1

                topLeftRadius: (atLeft && atTop) ? largeRadius : smallRadius
                topRightRadius: (atRight && atTop) ? largeRadius : smallRadius
                bottomLeftRadius: (atLeft && atBottom) ? largeRadius : smallRadius
                bottomRightRadius: (atRight && atBottom) ? largeRadius : smallRadius

                Behavior on x {
                    NumberAnimation { duration: OverviewConfig.animationDuration; easing.type: Easing.OutCubic }
                }
                Behavior on y {
                    NumberAnimation { duration: OverviewConfig.animationDuration; easing.type: Easing.OutCubic }
                }
            }
        }
    }
}
