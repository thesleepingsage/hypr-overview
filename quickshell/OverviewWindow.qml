pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland

/**
 * OverviewWindow - Individual window preview component
 * Shows a live preview of a window using ScreencopyView
 * Adapted from end-4/dots-hyprland for hypr-overview
 */
Item {
    id: root

    // Required properties
    property var toplevel           // Hyprland.toplevels entry (HyprlandToplevel)
    property var windowData         // HyprlandData client object
    property var monitorData        // Monitor info from HyprlandData
    property real scale: 1.0        // Overview scale factor
    property var widgetMonitor      // Monitor this widget is displayed on

    // Optional properties
    property real xOffset: 0
    property real yOffset: 0

    // Container color for corner masks (matches cluster background)
    property color containerColor: OverviewConfig.workspaceColor

    // Cascade mode (Board Mode) - when true, position is simplified for cluster layout
    property bool cascadeMode: false
    property int cascadeIndex: 0
    property real cascadeX: 0       // X position within cluster
    property real cascadeY: 0       // Y position within cluster
    property real cascadeWidth: 200 // Fixed width for cluster thumbnail
    property real cascadeHeight: 140 // Fixed height for cluster thumbnail

    // Interaction state (set by dragArea in OverviewWidget.qml)
    property bool hovered: false
    property bool pressed: false
    property bool isSwapTarget: false

    // Icon configuration from OverviewConfig
    property bool centerIcons: OverviewConfig.centerIcons
    property real iconGapRatio: 0.06
    property real iconToWindowRatio: centerIcons ? 0.35 : 0.15
    property real iconToWindowRatioCompact: 0.6

    // Computed properties
    property real widthRatio: {
        const widgetWidth = widgetMonitor?.width ?? 1920;
        const monitorWidth = monitorData?.width ?? 1920;
        return widgetWidth / monitorWidth;
    }

    property real heightRatio: {
        const widgetHeight = widgetMonitor?.height ?? 1080;
        const monitorHeight = monitorData?.height ?? 1080;
        return widgetHeight / monitorHeight;
    }

    property real initX: {
        const winX = windowData?.at?.[0] ?? 0;
        const monX = monitorData?.x ?? 0;
        const reserved = monitorData?.reserved?.[0] ?? 0;
        return Math.max((winX - monX - reserved) * widthRatio * root.scale, 0) + xOffset;
    }

    property real initY: {
        const winY = windowData?.at?.[1] ?? 0;
        const monY = monitorData?.y ?? 0;
        const reserved = monitorData?.reserved?.[1] ?? 0;
        return Math.max((winY - monY - reserved) * heightRatio * root.scale, 0) + yOffset;
    }

    property real targetWindowWidth: (windowData?.size?.[0] ?? 100) * scale * widthRatio
    property real targetWindowHeight: (windowData?.size?.[1] ?? 100) * scale * heightRatio

    property bool compactMode: targetWindowHeight < 60 || targetWindowWidth < 60

    // Icon resolution via shared helper
    property string iconPath: OverviewConfig.resolveIconPath(windowData?.class ?? "")

    property bool indicateXWayland: windowData?.xwayland ?? false

    // Position and size - cascade mode uses simplified layout
    x: cascadeMode ? cascadeX : initX
    y: cascadeMode ? cascadeY : initY
    width: cascadeMode ? cascadeWidth : targetWindowWidth
    height: cascadeMode ? cascadeHeight : targetWindowHeight

    // Z-order: in cascade mode, later windows on top
    z: cascadeMode ? cascadeIndex : 0

    // Dim windows from other monitors (only in grid mode)
    opacity: cascadeMode ? 1.0 : ((windowData?.monitor ?? -1) == (widgetMonitor?.id ?? -1) ? 1.0 : 0.4)

    // Corner radius (can be set by parent)
    property real cornerRadius: OverviewConfig.windowCornerRadius

    // Animations
    Behavior on x {
        NumberAnimation { duration: OverviewConfig.animationDuration; easing.type: Easing.OutCubic }
    }
    Behavior on y {
        NumberAnimation { duration: OverviewConfig.animationDuration; easing.type: Easing.OutCubic }
    }
    Behavior on width {
        NumberAnimation { duration: OverviewConfig.animationDuration; easing.type: Easing.OutCubic }
    }
    Behavior on height {
        NumberAnimation { duration: OverviewConfig.animationDuration; easing.type: Easing.OutCubic }
    }

    // Live window preview.
    // captureSource is the Wayland toplevel handle, exposed by HyprlandToplevel.wayland.
    ScreencopyView {
        id: windowPreview
        anchors.fill: parent
        captureSource: OverviewState.isOpen ? root.toplevel?.wayland ?? null : null
        live: true
    }

    // Corner masks - draw wedge shapes at each corner to create rounded appearance
    // Visual only - does not affect input hit areas (stays rectangular for drag/click)
    Repeater {
        model: 4  // TL=0, TR=1, BL=2, BR=3

        Shape {
            required property int index
            readonly property real r: root.cornerRadius

            // Position at each corner
            x: (index === 1 || index === 3) ? root.width - r : 0
            y: (index >= 2) ? root.height - r : 0
            width: r
            height: r
            z: 50  // Above window preview, below hover overlay

            layer.enabled: true
            layer.smooth: true

            ShapePath {
                fillColor: root.containerColor
                strokeWidth: 0

                // Each corner: arc curves AWAY from corner being masked
                // All use CCW which curves toward the interior/opposite corner
                // TL: (0,0)→(r,0)→arc to (0,r)  |  TR: (r,0)→(r,r)→arc to (0,0)
                // BL: (0,r)→(0,0)→arc to (r,r)  |  BR: (r,r)→(0,r)→arc to (r,0)
                startX: (index === 1 || index === 3) ? r : 0
                startY: (index >= 2) ? r : 0

                PathLine {
                    x: (index === 0) ? r : (index === 1) ? r : (index === 2) ? 0 : 0
                    y: (index === 0) ? 0 : (index === 1) ? r : (index === 2) ? 0 : r
                }

                PathArc {
                    x: (index === 0) ? 0 : (index === 1) ? 0 : (index === 2) ? r : r
                    y: (index === 0) ? r : (index === 1) ? 0 : (index === 2) ? r : 0
                    radiusX: r
                    radiusY: r
                    direction: PathArc.Counterclockwise  // All corners: arc curves away from corner
                }
            }
        }
    }

    // Overlay for hover/press states
    Rectangle {
        anchors.fill: parent
        radius: root.cornerRadius
        color: root.pressed ? Qt.rgba(1, 1, 1, 0.3) :
               root.hovered ? Qt.rgba(1, 1, 1, 0.15) :
               "transparent"
        border.color: Qt.rgba(1, 1, 1, 0.1)
        border.width: 1

        Behavior on color {
            ColorAnimation { duration: 150 }
        }
    }

    // App icon
    Image {
        id: windowIcon
        visible: OverviewConfig.showAppIcons
        property real baseSize: Math.min(root.width, root.height)  // Use actual rendered size (works for both grid and cascade mode)
        property real iconSize: baseSize * (root.compactMode ? root.iconToWindowRatioCompact : root.iconToWindowRatio)

        anchors {
            top: root.centerIcons ? undefined : parent.top
            left: root.centerIcons ? undefined : parent.left
            centerIn: root.centerIcons ? parent : undefined
            margins: baseSize * root.iconGapRatio
        }

        source: root.iconPath
        width: iconSize
        height: iconSize
        sourceSize: Qt.size(iconSize, iconSize)

        // XWayland indicator
        Rectangle {
            visible: root.indicateXWayland
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            width: parent.width * 0.35
            height: width
            radius: width / 2
            color: "#ff6b6b"

            Text {
                anchors.centerIn: parent
                text: "X"
                font.pixelSize: parent.width * 0.6
                font.bold: true
                color: "white"
            }
        }

        Behavior on width {
            NumberAnimation { duration: OverviewConfig.animationDuration; easing.type: Easing.OutCubic }
        }
        Behavior on height {
            NumberAnimation { duration: OverviewConfig.animationDuration; easing.type: Easing.OutCubic }
        }
    }

    // Swap target indicator (green highlight when dragging over this window)
    Rectangle {
        id: swapTargetIndicator
        visible: root.isSwapTarget
        anchors.fill: parent
        color: "transparent"
        border.color: Qt.rgba(0.4, 0.9, 0.4, 0.9)
        border.width: 3
        radius: root.cornerRadius
        z: 1001
    }

    // Tooltip on hover
    Rectangle {
        id: tooltip
        visible: root.hovered && !root.pressed && !root.isSwapTarget
        width: tooltipText.width + 16
        height: tooltipText.height + 8
        color: "#2d2d2d"
        radius: 4
        border.color: "#555"
        border.width: 1
        x: (parent.width - width) / 2
        y: -height - 8
        z: 1000

        Text {
            id: tooltipText
            anchors.centerIn: parent
            text: (root.windowData?.title ?? "Unknown") + "\n" + (root.windowData?.class ?? "")
            color: "#ffffff"
            font.pixelSize: 12
        }
    }

    // Stash action (called by dragArea in OverviewWidget.qml)
    function stashWindow(trayName) {
        if (!windowData?.address) return;
        if (!StashState.enabled) return;

        const wsId = windowData?.workspace?.id ?? -1;
        const wsName = windowData?.workspace?.name ?? String(wsId);

        StashState.stashWindow(
            windowData.address,
            trayName,
            wsId,
            wsName
        );

        console.log("[OverviewWindow] Stashed window", windowData.address, "to", trayName);
    }
}
