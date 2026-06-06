pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell

/**
 * StashTrayContainer - Container for multiple stash trays
 * Supports positioning on any edge: bottom, top, left, right
 * Exposes reservedSpace for cluster layout constraints
 */
Item {
    id: root

    // Required properties
    required property var monitorData
    required property var widgetMonitor

    // Config
    property string position: StashState.position
    property var trays: StashState.trays

    // State
    property bool hasStashedWindows: StashState.totalStashedCount > 0
    // Show stash tray if: enabled AND (has windows OR showEmptyTrays)
    property bool shouldShow: StashState.enabled &&
        (hasStashedWindows || StashState.showEmptyTrays)

    // Layout mode detection
    readonly property bool isVerticalLayout: position === "left" || position === "right"

    // Reserved space for cluster positioning constraints (exposed for BoardModeWidget)
    readonly property real reservedSpace: {
        if (!shouldShow) return 0
        // For vertical layout, reserve width; for horizontal, reserve height
        return isVerticalLayout ? implicitWidth : implicitHeight
    }

    // Size - depends on layout orientation
    visible: shouldShow

    implicitWidth: {
        if (!shouldShow) return 0
        const layoutItem = trayLayoutLoader.item
        if (!layoutItem) return 0
        return layoutItem.implicitWidth
    }

    implicitHeight: {
        if (!shouldShow) return 0
        if (isVerticalLayout && StashState.verticalFillMode === "full") {
            return parent?.height ?? 400
        }
        const layoutItem = trayLayoutLoader.item
        if (!layoutItem) return 0
        return layoutItem.implicitHeight
    }

    // Refresh when state changes
    Connections {
        target: StashState
        function onStateChanged() {
            root.hasStashedWindows = StashState.totalStashedCount > 0
        }
    }

    // Background
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0.08, 0.08, 0.08, 0.9)
        radius: 16

        // Dynamic layout - Row for horizontal positions, Column for vertical
        Loader {
            id: trayLayoutLoader
            anchors.centerIn: parent
            sourceComponent: root.isVerticalLayout ? columnLayout : rowLayout
        }

        Component {
            id: rowLayout
            Row {
                spacing: 12

                Repeater {
                    model: root.trays

                    delegate: StashTray {
                        required property var modelData
                        required property int index

                        trayName: modelData.name
                        trayLabel: modelData.label
                        monitorData: root.monitorData
                        widgetMonitor: root.widgetMonitor
                    }
                }
            }
        }

        Component {
            id: columnLayout
            Column {
                spacing: 12

                Repeater {
                    model: root.trays

                    delegate: StashTray {
                        required property var modelData
                        required property int index

                        trayName: modelData.name
                        trayLabel: modelData.label
                        monitorData: root.monitorData
                        widgetMonitor: root.widgetMonitor
                    }
                }
            }
        }
    }

    // Animations
    Behavior on implicitHeight {
        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
    }
    Behavior on implicitWidth {
        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
    }
}
