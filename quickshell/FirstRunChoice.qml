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
        width: 480
        height: 320
        radius: 16
        color: Qt.rgba(0.12, 0.12, 0.12, 0.95)
        border.color: Qt.rgba(1, 1, 1, 0.1)
        border.width: 1

        Column {
            anchors.fill: parent
            anchors.margins: 28
            anchors.bottomMargin: 32
            spacing: 16

            // Title
            Text {
                text: "Choose Your Overview Style"
                font.pixelSize: 22
                font.bold: true
                color: "white"
                anchors.horizontalCenter: parent.horizontalCenter
            }

            // Subtitle
            Text {
                text: "You can change this anytime by pressing M while the overview is open"
                font.pixelSize: 13
                color: Qt.rgba(1, 1, 1, 0.5)
                anchors.horizontalCenter: parent.horizontalCenter
                wrapMode: Text.WordWrap
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
            }

            // Spacer
            Item { width: 1; height: 4 }

            // Mode options row
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 20

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

        width: 195
        height: 165
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
            width: 85
            height: 18
            radius: 9
            color: "#4CAF50"

            Text {
                anchors.centerIn: parent
                text: "Recommended"
                font.pixelSize: 9
                font.bold: true
                color: "white"
            }
        }

        Column {
            anchors.fill: parent
            anchors.margins: 14
            anchors.topMargin: option.isRecommended ? 16 : 14
            spacing: 8

            // Icon
            Text {
                text: option.iconText
                font.pixelSize: 36
                color: "white"
                anchors.horizontalCenter: parent.horizontalCenter
            }

            // Mode name
            Text {
                text: option.modeName
                font.pixelSize: 15
                font.bold: true
                color: "white"
                anchors.horizontalCenter: parent.horizontalCenter
            }

            // Description
            Text {
                text: option.modeDescription
                font.pixelSize: 11
                color: Qt.rgba(1, 1, 1, 0.6)
                anchors.horizontalCenter: parent.horizontalCenter
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                width: parent.width
                lineHeight: 1.2
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
