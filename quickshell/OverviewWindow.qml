pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
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
    property var toplevel           // ToplevelManager.toplevels entry
    property var windowData         // HyprlandData client object
    property var monitorData        // Monitor info from HyprlandData
    property real scale: 1.0        // Overview scale factor
    property var widgetMonitor      // Monitor this widget is displayed on

    // Optional properties
    property real xOffset: 0
    property real yOffset: 0

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

    // Position and size
    x: initX
    y: initY
    width: targetWindowWidth
    height: targetWindowHeight

    // Dim windows from other monitors
    opacity: (windowData?.monitor ?? -1) == (widgetMonitor?.id ?? -1) ? 1.0 : 0.4

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

    // Live window preview
    ScreencopyView {
        id: windowPreview
        anchors.fill: parent
        captureSource: OverviewState.isOpen ? root.toplevel : null
        live: true
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
        property real baseSize: Math.min(root.targetWindowWidth, root.targetWindowHeight)
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
