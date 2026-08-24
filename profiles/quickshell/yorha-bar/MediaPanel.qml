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
    margins.left: (screen.width / 2) - 400
    implicitWidth: 260
    implicitHeight: opened ? 150 : 0
    color: "transparent"

    property bool opened: false
    function toggle() { opened = !opened; if (opened) refresh() }
    function refresh() { titleProc.running = true }

    Behavior on implicitHeight {
        NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
    }

    Process {
        id: titleProc
        command: ["sh", "-c", "playerctl metadata --format '{{title}} - {{artist}}' 2>/dev/null || echo 'nothing playing'"]
        stdout: SplitParser { onRead: data => titleText.text = data.trim() }
    }
    Timer { interval: 2000; running: root.opened; repeat: true; onTriggered: root.refresh() }

    Item {
        anchors.fill: parent
        clip: true

        Rectangle {
            width: parent.width
            height: 150
            y: root.opened ? 0 : -150
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

                Text { text: "\uf001  now playing"; color: "#F4A144"; font.pixelSize: 11; anchors.horizontalCenter: parent.horizontalCenter }
                Text { id: titleText; text: "loading..."; color: "#FFC968"; font.pixelSize: 13; anchors.horizontalCenter: parent.horizontalCenter }

                Row {
                    spacing: 24
                    anchors.horizontalCenter: parent.horizontalCenter
                    Text { text: "⏮"; color: "#F4A144"; font.pixelSize: 18
                        MouseArea { anchors.fill: parent; onClicked: playerctlCmd.exec(["playerctl","previous"]) } }
                    Text { text: "⏯"; color: "#FFC968"; font.pixelSize: 20
                        MouseArea { anchors.fill: parent; onClicked: playerctlCmd.exec(["playerctl","play-pause"]) } }
                    Text { text: "⏭"; color: "#F4A144"; font.pixelSize: 18
                        MouseArea { anchors.fill: parent; onClicked: playerctlCmd.exec(["playerctl","next"]) } }
                }
            }
        }
    }

    Process { id: playerctlCmd; function exec(cmd) { command = cmd; running = true } }
}
