import Quickshell
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: root
    visible: true
    anchors.top: true
    anchors.left: true
    margins.top: 40
    margins.left: (screen.width / 2) + 140
    implicitWidth: 260
    implicitHeight: opened ? 160 : 0
    color: "transparent"

    property bool opened: false
    function toggle() { opened = !opened }

    Behavior on implicitHeight {
        NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
    }

    Item {
        anchors.fill: parent
        clip: true

        Rectangle {
            width: parent.width
            height: 160
            y: root.opened ? 0 : -160
            Behavior on y { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
            color: "#0a0f12"
            border.color: "#F4A14466"
            border.width: 1
            radius: 12
            opacity: root.opened ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 180 } }

            Rectangle { width: parent.width; height: 3; color: "#F4A144"; radius: 2; anchors.top: parent.top }

            Column {
                anchors.centerIn: parent
                spacing: 6
                Text { text: "\uf073  calendar"; color: "#F4A144"; font.pixelSize: 11; anchors.horizontalCenter: parent.horizontalCenter }
                Text { text: Qt.formatDate(new Date(), "MMMM yyyy"); color: "#FFC968"; font.pixelSize: 18; font.bold: true; anchors.horizontalCenter: parent.horizontalCenter }
                Text { text: Qt.formatDate(new Date(), "dddd, dd"); color: Qt.rgba(1,0.79,0.4,0.6); font.pixelSize: 12; anchors.horizontalCenter: parent.horizontalCenter }
            }
        }
    }
}
