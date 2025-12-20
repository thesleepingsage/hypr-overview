pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell

/**
 * StashTrayContainer - Container for multiple stash trays
 * Positioned at the bottom of the overview widget
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
    property bool shouldShow: StashState.enabled && (hasStashedWindows || StashState.showEmptyTrays)

    // Size
    visible: shouldShow
    implicitWidth: trayRow.implicitWidth + 20
    implicitHeight: shouldShow ? trayRow.implicitHeight + 20 : 0

    // Refresh when state changes
    Connections {
        target: StashState
        function onStateChanged() {
            root.hasStashedWindows = StashState.totalStashedCount > 0;
        }
    }

    // Background
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0.08, 0.08, 0.08, 0.9)
        radius: 16

        // Trays layout
        Row {
            id: trayRow
            anchors.centerIn: parent
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

    // Animation
    Behavior on implicitHeight {
        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
    }
}
