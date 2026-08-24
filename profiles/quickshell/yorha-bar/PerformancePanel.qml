import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick

PanelWindow {
    id: root
    visible: true
    anchors.top: true
    anchors.left: true
    margins.top: 40
    margins.left: (screen.width / 2) - 130
    implicitWidth: 260
    implicitHeight: opened ? 160 : 0
    color: "transparent"

    property bool opened: false
    function toggle() { opened = !opened; if (opened) refresh() }
    function refresh() { cpuProc.running = true; memProc.running = true }

    Behavior on implicitHeight {
        NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
    }

    Process {
        id: cpuProc
        command: ["sh", "-c", "top -bn1 | grep 'Cpu(s)' | awk '{print $2}'"]
        stdout: SplitParser { onRead: data => cpuText.text = data.trim() + "%" }
    }
    Process {
        id: memProc
        command: ["sh", "-c", "free -m | awk '/Mem:/ {printf \"%.0f / %.0f MB\", $3, $2}'"]
        stdout: SplitParser { onRead: data => memText.text = data }
    }
    Timer { interval: 2000; running: root.opened; repeat: true; onTriggered: root.refresh() }

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
                spacing: 14
                width: parent.width - 40

                Text { text: "\uf2db  performance"; color: "#F4A144"; font.pixelSize: 11; anchors.horizontalCenter: parent.horizontalCenter }

                Row {
                    width: parent.width
                    Text { text: "CPU"; color: Qt.rgba(1,0.79,0.4,0.6); font.pixelSize: 13; width: parent.width/2 }
                    Text { id: cpuText; text: "--%"; color: "#FFC968"; font.pixelSize: 13; font.bold: true; width: parent.width/2; horizontalAlignment: Text.AlignRight }
                }
                Row {
                    width: parent.width
                    Text { text: "RAM"; color: Qt.rgba(1,0.79,0.4,0.6); font.pixelSize: 13; width: parent.width/2 }
                    Text { id: memText; text: "--"; color: "#FFC968"; font.pixelSize: 13; font.bold: true; width: parent.width/2; horizontalAlignment: Text.AlignRight }
                }
            }
        }
    }
}
