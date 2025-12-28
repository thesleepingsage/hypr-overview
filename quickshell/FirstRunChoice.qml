import QtQuick
import QtQuick.Controls

// First-run mode choice dialog
// Shows on first launch to let user choose between Grid and Board mode
Item {
    id: root
    anchors.fill: parent
    visible: OverviewState.isFirstRun && OverviewState.isOpen

    // Semi-transparent backdrop
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.7)

        MouseArea {
            anchors.fill: parent
            // Block clicks from going through
        }
    }

    // Dialog container
    Rectangle {
        id: dialog
        anchors.centerIn: parent
        width: 500
        height: 340
        radius: 16
        color: Qt.rgba(0.15, 0.15, 0.15, 0.95)
        border.color: Qt.rgba(1, 1, 1, 0.1)
        border.width: 1

        Column {
            anchors.fill: parent
            anchors.margins: 32
            spacing: 24

            // Title
            Text {
                text: "Choose Your Overview Style"
                font.pixelSize: 24
                font.bold: true
                color: "white"
                anchors.horizontalCenter: parent.horizontalCenter
            }

            // Subtitle
            Text {
                text: "You can change this anytime by pressing M while the overview is open"
                font.pixelSize: 14
                color: Qt.rgba(1, 1, 1, 0.6)
                anchors.horizontalCenter: parent.horizontalCenter
                wrapMode: Text.WordWrap
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
            }

            // Spacer
            Item { width: 1; height: 8 }

            // Mode options row
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 24

                // Grid Mode option
                ModeOption {
                    modeName: "Grid Mode"
                    modeDescription: "Traditional grid layout.\nWorkspaces in a fixed arrangement."
                    iconText: "▦"
                    isRecommended: false
                    onSelected: {
                        OverviewState.setMode("grid")
                        console.log("[hypr-overview] First-run: Grid Mode selected")
                    }
                }

                // Board Mode option
                ModeOption {
                    modeName: "Board Mode"
                    modeDescription: "Freeform workspace clusters.\nDrag to arrange, Alt+click to reveal."
                    iconText: "◫"
                    isRecommended: true
                    onSelected: {
                        OverviewState.setMode("board")
                        console.log("[hypr-overview] First-run: Board Mode selected")
                    }
                }
            }
        }
    }

    // Subtle entrance animation
    opacity: visible ? 1 : 0
    Behavior on opacity {
        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
    }

    // ModeOption component
    component ModeOption: Rectangle {
        id: option
        property string modeName: ""
        property string modeDescription: ""
        property string iconText: ""
        property bool isRecommended: false
        signal selected()

        width: 200
        height: 180
        radius: 12
        color: mouseArea.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(1, 1, 1, 0.08)
        border.color: mouseArea.containsMouse ? Qt.rgba(1, 1, 1, 0.4) : Qt.rgba(1, 1, 1, 0.15)
        border.width: mouseArea.containsMouse ? 2 : 1

        Behavior on color { ColorAnimation { duration: 150 } }
        Behavior on border.color { ColorAnimation { duration: 150 } }

        // Recommended badge
        Rectangle {
            visible: option.isRecommended
            anchors.top: parent.top
            anchors.topMargin: -8
            anchors.horizontalCenter: parent.horizontalCenter
            width: 90
            height: 20
            radius: 10
            color: "#4CAF50"

            Text {
                anchors.centerIn: parent
                text: "Recommended"
                font.pixelSize: 10
                font.bold: true
                color: "white"
            }
        }

        Column {
            anchors.fill: parent
            anchors.margins: 16
            anchors.topMargin: option.isRecommended ? 20 : 16
            spacing: 12

            // Icon
            Text {
                text: option.iconText
                font.pixelSize: 48
                color: "white"
                anchors.horizontalCenter: parent.horizontalCenter
            }

            // Mode name
            Text {
                text: option.modeName
                font.pixelSize: 16
                font.bold: true
                color: "white"
                anchors.horizontalCenter: parent.horizontalCenter
            }

            // Description
            Text {
                text: option.modeDescription
                font.pixelSize: 12
                color: Qt.rgba(1, 1, 1, 0.7)
                anchors.horizontalCenter: parent.horizontalCenter
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                width: parent.width
            }
        }

        MouseArea {
            id: mouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: option.selected()
        }
    }
}
