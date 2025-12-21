pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

/**
 * StashTray - Single stash tray visual component
 * Displays stashed windows for a specific tray
 */
Rectangle {
    id: root

    // Required properties
    required property string trayName
    required property string trayLabel
    required property var monitorData
    required property var widgetMonitor

    // Config
    property real previewScale: StashState.previewScale

    // State
    property var stashedWindows: StashState.getWindowsForTray(trayName)
    property int windowCount: stashedWindows.length
    property bool isEmpty: windowCount === 0
    property bool collapsed: isEmpty && !StashState.showEmptyTrays

    // Group windows by origin workspace
    property var windowsByWorkspace: {
        const groups = {};
        for (const win of stashedWindows) {
            const wsKey = win.originWorkspace;
            if (!groups[wsKey]) {
                groups[wsKey] = {
                    id: win.originWorkspace,
                    name: win.originWorkspaceName || String(win.originWorkspace),
                    windows: []
                };
            }
            groups[wsKey].windows.push(win);
        }
        // Convert to sorted array
        return Object.values(groups).sort((a, b) => a.id - b.id);
    }

    // Visual properties
    property real trayHeight: 100
    property real windowPreviewWidth: 120
    property real windowPreviewHeight: 80
    property real trayPadding: 8
    property real cornerRadius: 12

    // Colors
    property color backgroundColor: Qt.rgba(0.12, 0.12, 0.12, 0.95)
    property color borderColor: Qt.rgba(0.3, 0.3, 0.3, 0.5)
    property color labelColor: Qt.rgba(1, 1, 1, 0.7)
    property color countBadgeColor: Qt.rgba(0.4, 0.6, 1.0, 0.9)

    // Size
    visible: !collapsed
    implicitWidth: collapsed ? 0 : Math.max(200, contentRow.implicitWidth + trayPadding * 2)
    implicitHeight: collapsed ? 0 : trayHeight + trayPadding * 2

    // Appearance
    color: backgroundColor
    radius: cornerRadius
    border.color: borderColor
    border.width: 1

    // Refresh when state changes
    Connections {
        target: StashState
        function onStateChanged() {
            root.stashedWindows = StashState.getWindowsForTray(root.trayName);
        }
    }

    // Content layout
    RowLayout {
        id: contentRow
        anchors.fill: parent
        anchors.margins: trayPadding
        spacing: 8

        // Tray label and count
        ColumnLayout {
            Layout.preferredWidth: 80
            Layout.fillHeight: true
            spacing: 4

            Text {
                text: root.trayLabel
                color: labelColor
                font.pixelSize: 12
                font.weight: Font.Medium
            }

            // Count badge
            Rectangle {
                visible: root.windowCount > 0
                width: 24
                height: 24
                radius: 12
                color: countBadgeColor

                Text {
                    anchors.centerIn: parent
                    text: root.windowCount
                    color: "white"
                    font.pixelSize: 11
                    font.bold: true
                }
            }

            Item { Layout.fillHeight: true }
        }

        // Separator
        Rectangle {
            Layout.preferredWidth: 1
            Layout.fillHeight: true
            Layout.margins: 4
            color: borderColor
            visible: root.windowCount > 0
        }

        // Grouped window previews by origin workspace
        Row {
            id: windowsRow
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 12

            Repeater {
                model: root.windowsByWorkspace

                delegate: Row {
                    id: workspaceGroup
                    required property var modelData
                    required property int index

                    spacing: 4

                    // Workspace label
                    Rectangle {
                        width: 20
                        height: root.windowPreviewHeight
                        color: Qt.rgba(0.3, 0.5, 0.8, 0.3)
                        radius: 4

                        Text {
                            anchors.centerIn: parent
                            text: workspaceGroup.modelData.name
                            color: Qt.rgba(1, 1, 1, 0.8)
                            font.pixelSize: 12
                            font.bold: true
                        }
                    }

                    // Windows in this workspace group
                    Row {
                        spacing: 4

                        Repeater {
                            model: workspaceGroup.modelData.windows

                            delegate: Rectangle {
                                id: windowPreview
                                required property var modelData
                                required property int index

                                property string windowAddress: modelData.address
                                property var windowData: HyprlandData.windowByAddress[windowAddress]
                                property var toplevel: {
                                    const toplevels = ToplevelManager.toplevels.values;
                                    const addr = windowAddress.replace("0x", "");
                                    return toplevels.find(t => t.HyprlandToplevel?.address === addr);
                                }

                                width: root.windowPreviewWidth
                                height: root.windowPreviewHeight
                                color: Qt.rgba(0.2, 0.2, 0.2, 1)
                                radius: 6
                                clip: true

                                // Hover state
                                property bool hovered: false
                                border.color: hovered ? Qt.rgba(0.5, 0.7, 1.0, 0.8) : "transparent"
                                border.width: 2

                                // Live preview if available
                                ScreencopyView {
                                    anchors.fill: parent
                                    anchors.margins: 2
                                    captureSource: OverviewState.isOpen ? windowPreview.toplevel : null
                                    live: true
                                    visible: toplevel !== undefined
                                }

                                // Fallback: app icon
                                Image {
                                    anchors.centerIn: parent
                                    width: 32
                                    height: 32
                                    visible: windowPreview.toplevel === undefined
                                    source: OverviewConfig.resolveIconPath(windowPreview.windowData?.class ?? "")
                                }

                                // Window title tooltip
                                Rectangle {
                                    visible: windowPreview.hovered
                                    anchors.bottom: parent.top
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.bottomMargin: 4
                                    width: titleText.width + 12
                                    height: titleText.height + 6
                                    color: "#2d2d2d"
                                    radius: 4
                                    z: 100

                                    Text {
                                        id: titleText
                                        anchors.centerIn: parent
                                        text: windowPreview.windowData?.title ?? "Unknown"
                                        color: "white"
                                        font.pixelSize: 10
                                        maximumLineCount: 1
                                        elide: Text.ElideRight
                                    }
                                }

                                // Click to restore
                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    acceptedButtons: Qt.LeftButton

                                    onEntered: windowPreview.hovered = true
                                    onExited: windowPreview.hovered = false

                                    onClicked: (mouse) => {
                                        // When configured modifier is held, restore without focus (mouse stays on overview)
                                        const shouldFocus = !StashState.isModifierHeld(mouse.modifiers);
                                        StashState.unstashWindow(windowPreview.windowAddress, shouldFocus);
                                        console.log("[StashTray] Restored window", windowPreview.windowAddress, "focus:", shouldFocus);
                                    }
                                }

                                // Animation
                                Behavior on opacity {
                                    NumberAnimation { duration: 150 }
                                }
                            }
                        }
                    }

                    // Separator between workspace groups
                    Rectangle {
                        visible: workspaceGroup.index < root.windowsByWorkspace.length - 1
                        width: 1
                        height: parent.height - 16
                        anchors.verticalCenter: parent.verticalCenter
                        color: Qt.rgba(1, 1, 1, 0.2)
                    }
                }
            }
        }

        // Empty state message
        Text {
            visible: root.isEmpty && StashState.showEmptyTrays
            text: "Drop windows here"
            color: Qt.rgba(1, 1, 1, 0.3)
            font.pixelSize: 11
            font.italic: true
        }
    }

    // Drop area for stashing via drag
    DropArea {
        anchors.fill: parent

        onEntered: (drag) => {
            root.border.color = Qt.rgba(0.4, 0.9, 0.4, 0.9);
            root.border.width = 2;
        }

        onExited: {
            root.border.color = borderColor;
            root.border.width = 1;
        }

        onDropped: (drop) => {
            root.border.color = borderColor;
            root.border.width = 1;

            // Get the dropped window address from the drag source
            if (drop.source && drop.source.address) {
                const windowData = HyprlandData.windowByAddress[drop.source.address];
                if (windowData) {
                    StashState.stashWindow(
                        drop.source.address,
                        root.trayName,
                        windowData.workspace.id,
                        windowData.workspace.name
                    );
                    console.log("[StashTray] Stashed dropped window", drop.source.address, "to", root.trayName);
                }
            }
        }
    }
}
