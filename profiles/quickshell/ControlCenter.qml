import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Controls

PanelWindow {
    id: root
    visible: true
    anchors.top: true
    anchors.right: true
    margins.top: 46
    margins.right: 16
    implicitWidth: 280
    implicitHeight: opened ? 340 : 0
    color: "transparent"

    property bool opened: false
    property bool wifiOn: true
    property bool btOn: false
    property bool dndOn: false

    function toggle() { opened = !opened }

    Behavior on implicitHeight {
        NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
    }

    Process { id: volUp; command: ["wpctl","set-volume","@DEFAULT_AUDIO_SINK@","5%+"] }
    Process { id: volDown; command: ["wpctl","set-volume","@DEFAULT_AUDIO_SINK@","5%-"] }
    Process { id: brightUp; command: ["brightnessctl","set","5%+"] }
    Process { id: brightDown; command: ["brightnessctl","set","5%-"] }
    Process { id: lockCmd; command: ["hyprlock"] }
    Process { id: logoutCmd; command: ["hyprctl","dispatch","exit"] }
    Process { id: shutdownCmd; command: ["systemctl","poweroff"] }

    Item {
        anchors.fill: parent
        clip: true

        Rectangle {
            width: parent.width
            height: 340
            y: root.opened ? 0 : -340
            Behavior on y { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
            color: "#0a0f12"
            border.color: "#F4A14466"
            border.width: 1
            radius: 14
            opacity: root.opened ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 180 } }

            Rectangle { width: parent.width; height: 3; color: "#F4A144"; radius: 2; anchors.top: parent.top }

            Column {
                anchors.top: parent.top
                anchors.topMargin: 20
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width - 40
                spacing: 16

                Text { text: "control center"; color: "#F4A144"; font.pixelSize: 11 }

                // Toggle row
                Row {
                    width: parent.width
                    spacing: 8

                    Rectangle {
                        width: (parent.width - 16) / 3; height: 44; radius: 10
                        color: root.wifiOn ? "#F4A144" : "#1a2226"
                        Column {
                            anchors.centerIn: parent
                            Text { text: "\uf1eb"; color: root.wifiOn ? "#010507" : "#FFC968"; font.pixelSize: 14; anchors.horizontalCenter: parent.horizontalCenter }
                            Text { text: "wifi"; color: root.wifiOn ? "#010507" : "#FFC968"; font.pixelSize: 9; anchors.horizontalCenter: parent.horizontalCenter }
                        }
                        MouseArea { anchors.fill: parent; onClicked: root.wifiOn = !root.wifiOn }
                    }
                    Rectangle {
                        width: (parent.width - 16) / 3; height: 44; radius: 10
                        color: root.btOn ? "#F4A144" : "#1a2226"
                        Column {
                            anchors.centerIn: parent
                            Text { text: "\uf294"; color: root.btOn ? "#010507" : "#FFC968"; font.pixelSize: 14; anchors.horizontalCenter: parent.horizontalCenter }
                            Text { text: "bluetooth"; color: root.btOn ? "#010507" : "#FFC968"; font.pixelSize: 9; anchors.horizontalCenter: parent.horizontalCenter }
                        }
                        MouseArea { anchors.fill: parent; onClicked: root.btOn = !root.btOn }
                    }
                    Rectangle {
                        width: (parent.width - 16) / 3; height: 44; radius: 10
                        color: root.dndOn ? "#F4A144" : "#1a2226"
                        Column {
                            anchors.centerIn: parent
                            Text { text: "\uf1f6"; color: root.dndOn ? "#010507" : "#FFC968"; font.pixelSize: 14; anchors.horizontalCenter: parent.horizontalCenter }
                            Text { text: "dnd"; color: root.dndOn ? "#010507" : "#FFC968"; font.pixelSize: 9; anchors.horizontalCenter: parent.horizontalCenter }
                        }
                        MouseArea { anchors.fill: parent; onClicked: root.dndOn = !root.dndOn }
                    }
                }

                // Volume slider row
                Row {
                    width: parent.width
                    spacing: 10
                    Text { text: "\uf028"; color: "#FFC968"; font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter }
                    Slider {
                        width: parent.width - 30
                        from: 0; to: 100; value: 50
                        onMoved: value > 50 ? volUp.running = true : volDown.running = true
                    }
                }

                // Brightness slider row
                Row {
                    width: parent.width
                    spacing: 10
                    Text { text: "\uf185"; color: "#FFC968"; font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter }
                    Slider {
                        width: parent.width - 30
                        from: 0; to: 100; value: 70
                        onMoved: value > 70 ? brightUp.running = true : brightDown.running = true
                    }
                }

                // Session row
                Row {
                    width: parent.width
                    spacing: 10
                    Rectangle {
                        width: (parent.width - 20) / 3; height: 34; radius: 8; color: "#1a2226"
                        Text { anchors.centerIn: parent; text: "\uf023 lock"; color: "#FFC968"; font.pixelSize: 10 }
                        MouseArea { anchors.fill: parent; onClicked: lockCmd.running = true }
                    }
                    Rectangle {
                        width: (parent.width - 20) / 3; height: 34; radius: 8; color: "#1a2226"
                        Text { anchors.centerIn: parent; text: "\uf2f5 logout"; color: "#FFC968"; font.pixelSize: 10 }
                        MouseArea { anchors.fill: parent; onClicked: logoutCmd.running = true }
                    }
                    Rectangle {
                        width: (parent.width - 20) / 3; height: 34; radius: 8; color: "#633D3D"
                        Text { anchors.centerIn: parent; text: "\uf011 power"; color: "#FFC968"; font.pixelSize: 10 }
                        MouseArea { anchors.fill: parent; onClicked: shutdownCmd.running = true }
                    }
                }
            }
        }
    }
}
