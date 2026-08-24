import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

PanelWindow {
    id: bar
    anchors.top: true
    anchors.left: true
    anchors.right: true
    implicitHeight: 40
    color: "transparent"

    property color gold: "#FFC968"
    property color accent: "#F4A144"
    property color slate: "#1a2226"
    property int activeWorkspace: 1

    property var calendarPanelRef
    property var perfPanelRef
    property var mediaPanelRef
    property var controlCenterRef

    Rectangle {
        anchors.fill: parent
        color: "#010507"
        opacity: 0.85
    }

    Process {
        id: activeWsProc
        command: ["hyprctl", "activeworkspace", "-j"]
        stdout: SplitParser {
            onRead: data => {
                try {
                    const parsed = JSON.parse(data)
                    bar.activeWorkspace = parsed.id
                } catch (e) {}
            }
        }
    }
    Timer {
        interval: 500
        running: true
        repeat: true
        onTriggered: activeWsProc.running = true
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        spacing: 10

        // Workspaces capsule
        Rectangle {
            Layout.preferredHeight: 26
            Layout.preferredWidth: wsRow.implicitWidth + 16
            radius: 8
            color: bar.slate
            border.color: Qt.rgba(0.96,0.63,0.27,0.25)
            border.width: 1

            Row {
                id: wsRow
                anchors.centerIn: parent
                spacing: 4
                Repeater {
                    model: ["壱", "弐", "参", "四", "伍"]
                    delegate: Rectangle {
                        width: 22; height: 20; radius: 6
                        color: (index + 1) === bar.activeWorkspace ? bar.accent : "transparent"
                        Behavior on color { ColorAnimation { duration: 150 } }
                        Text {
                            anchors.centerIn: parent
                            text: modelData
                            color: (index + 1) === bar.activeWorkspace ? "#010507" : Qt.rgba(1,1,1,0.4)
                            font.pixelSize: 11
                            font.family: "Noto Sans CJK JP"
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: wsProc.exec(["hyprctl","dispatch","workspace",(index+1).toString()])
                        }
                    }
                }
            }
        }

        Item { Layout.fillWidth: true }

        // Media capsule (hover expand)
        Rectangle {
            id: mediaCap
            Layout.preferredHeight: 26
            Layout.preferredWidth: mediaHover.containsMouse ? 150 : 30
            Behavior on Layout.preferredWidth { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
            radius: 8
            color: bar.slate
            border.color: Qt.rgba(0.96,0.63,0.27,0.25)
            border.width: 1
            clip: true

            MouseArea {
                id: mediaHover
                anchors.fill: parent
                hoverEnabled: true
                onClicked: bar.mediaPanelRef.toggle()
            }

            Row {
                anchors.centerIn: parent
                spacing: 6
                Text { text: "\uf001"; color: bar.gold; font.pixelSize: 12 }
                Text {
                    text: "media"
                    color: bar.gold
                    font.pixelSize: 11
                    width: mediaHover.containsMouse ? implicitWidth : 0
                    clip: true
                    opacity: mediaHover.containsMouse ? 1 : 0
                    Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                    Behavior on opacity { NumberAnimation { duration: 120 } }
                }
            }
        }

        // Clock capsule (always expanded, center focal point)
        Rectangle {
            Layout.preferredHeight: 26
            Layout.preferredWidth: clockText.implicitWidth + 24
            radius: 8
            color: bar.accent
            Text {
                id: clockText
                anchors.centerIn: parent
                color: "#010507"
                font.pixelSize: 12
                font.bold: true
                function updateClock() { text = Qt.formatDateTime(new Date(), "hh:mm  ddd dd MMM") }
                Component.onCompleted: updateClock()
                Timer { interval: 1000; running: true; repeat: true; onTriggered: clockText.updateClock() }
            }
            MouseArea { anchors.fill: parent; onClicked: bar.calendarPanelRef.toggle() }
        }

        // Performance capsule (hover expand)
        Rectangle {
            id: perfCap
            Layout.preferredHeight: 26
            Layout.preferredWidth: perfHover.containsMouse ? 130 : 30
            Behavior on Layout.preferredWidth { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
            radius: 8
            color: bar.slate
            border.color: Qt.rgba(0.96,0.63,0.27,0.25)
            border.width: 1
            clip: true

            MouseArea {
                id: perfHover
                anchors.fill: parent
                hoverEnabled: true
                onClicked: bar.perfPanelRef.toggle()
            }

            Row {
                anchors.centerIn: parent
                spacing: 6
                Text { text: "\uf2db"; color: bar.gold; font.pixelSize: 12 }
                Text {
                    text: "perf"
                    color: bar.gold
                    font.pixelSize: 11
                    width: perfHover.containsMouse ? implicitWidth : 0
                    clip: true
                    opacity: perfHover.containsMouse ? 1 : 0
                    Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                    Behavior on opacity { NumberAnimation { duration: 120 } }
                }
            }
        }

        Item { Layout.fillWidth: true }

        // Status + control center capsule
        Rectangle {
            Layout.preferredHeight: 26
            Layout.preferredWidth: statusRow.implicitWidth + 20
            radius: 8
            color: bar.slate
            border.color: Qt.rgba(0.96,0.63,0.27,0.25)
            border.width: 1

            Row {
                id: statusRow
                anchors.centerIn: parent
                spacing: 12

                Text { text: "\uf1eb"; color: bar.gold; font.pixelSize: 12 }
                Text { text: "\uf028"; color: bar.gold; font.pixelSize: 12 }
                Text { text: "\uf240"; color: bar.gold; font.pixelSize: 12 }

                Rectangle {
                    width: 22; height: 20; radius: 6; color: "transparent"
                    Text { anchors.centerIn: parent; text: "\uf013"; color: bar.accent; font.pixelSize: 13 }
                    MouseArea { anchors.fill: parent; onClicked: bar.controlCenterRef.toggle() }
                }
            }
        }
    }

    Process {
        id: wsProc
        function exec(cmd) { command = cmd; running = true }
    }
}
