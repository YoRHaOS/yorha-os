import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

PanelWindow {
    id: bar
    // Top-right corner, sized to its content (not full monitor width). Anchoring
    // to top+right only (no left) lets the layer-surface width follow implicitWidth.
    anchors.top: true
    anchors.right: true
    margins.top: 6
    margins.right: 12
    implicitHeight: 40
    implicitWidth: barRow.implicitWidth + 32
    color: "transparent"

    // Locked LIGHT palette (docs/visual-identity.md) — no wallust dark values.
    readonly property color cSand:     "#d3cdb6"   // bar fill
    readonly property color cPanel:    "#dcd7c3"   // capsule fill
    readonly property color cInk:      "#4a4739"   // primary text
    readonly property color cInkSoft:  "#6b6754"   // secondary text
    readonly property color cInkFaint: "#8d8873"   // muted text
    readonly property color cRule:     "#8d8873"
    readonly property color cHot:      "#bb5b32"   // accent
    readonly property color cActiveText:"#d3cdb6"  // label on accent
    readonly property string mono: "JetBrainsMono Nerd Font"

    property int activeWorkspace: 1

    // Single unified panel; capsules open it at a specific view.
    property var controlCenterRef

    // Rounded floating capsule (no longer a full-width edge strip)
    Rectangle { anchors.fill: parent; radius: 10; color: bar.cSand }

    Process {
        id: activeWsProc
        command: ["hyprctl", "activeworkspace", "-j"]
        stdout: SplitParser {
            onRead: data => { try { bar.activeWorkspace = JSON.parse(data).id } catch (e) {} }
        }
    }
    Timer { interval: 500; running: true; repeat: true; onTriggered: activeWsProc.running = true }

    RowLayout {
        id: barRow
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        spacing: 10

        // Workspaces capsule
        Rectangle {
            Layout.preferredHeight: 26
            Layout.preferredWidth: wsRow.implicitWidth + 16
            radius: 8
            color: bar.cPanel
            Row {
                id: wsRow
                anchors.centerIn: parent
                spacing: 4
                Repeater {
                    model: ["壱", "弐", "参", "四", "伍"]
                    delegate: Rectangle {
                        width: 22; height: 20; radius: 6
                        color: (index + 1) === bar.activeWorkspace ? bar.cHot : "transparent"
                        Behavior on color { ColorAnimation { duration: 150; easing.type: Easing.OutExpo } }
                        Text {
                            anchors.centerIn: parent
                            text: modelData
                            color: (index + 1) === bar.activeWorkspace ? bar.cActiveText : bar.cInkFaint
                            font.pixelSize: 11
                            font.family: "Noto Sans CJK JP"   // kanji: Nerd Font lacks CJK coverage
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: wsProc.exec(["hyprctl","dispatch","workspace",(index+1).toString()])
                        }
                    }
                }
            }
        }


        // Media capsule → opens control center Home
        Rectangle {
            id: mediaCap
            Layout.preferredHeight: 26
            Layout.preferredWidth: mediaHover.containsMouse ? 150 : 30
            Behavior on Layout.preferredWidth { NumberAnimation { duration: 160; easing.type: Easing.OutExpo } }
            radius: 8; color: bar.cPanel; clip: true
            MouseArea {
                id: mediaHover; anchors.fill: parent; hoverEnabled: true
                onClicked: bar.controlCenterRef.openView("home")
            }
            Row {
                anchors.centerIn: parent; spacing: 6
                Text { text: "\uf001"; color: bar.cInkSoft; font.family: bar.mono; font.pixelSize: 12 }
                Text {
                    text: "media"; color: bar.cInkSoft; font.family: bar.mono; font.pixelSize: 11
                    width: mediaHover.containsMouse ? implicitWidth : 0   // animate width with opacity (layout width)
                    clip: true
                    opacity: mediaHover.containsMouse ? 1 : 0
                    Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutExpo } }
                    Behavior on opacity { NumberAnimation { duration: 120 } }
                }
            }
        }

        // Clock capsule (accent focal point) → opens Calendar view
        Rectangle {
            Layout.preferredHeight: 26
            Layout.preferredWidth: clockText.implicitWidth + 24
            radius: 8; color: bar.cHot
            Text {
                id: clockText
                anchors.centerIn: parent
                color: bar.cActiveText
                font.family: bar.mono; font.pixelSize: 12; font.bold: true
                function updateClock() { text = Qt.formatDateTime(new Date(), "HH:mm  ddd dd MMM") }
                Component.onCompleted: updateClock()
                Timer { interval: 1000; running: true; repeat: true; onTriggered: clockText.updateClock() }
            }
            MouseArea { anchors.fill: parent; onClicked: bar.controlCenterRef.openView("calendar") }
        }

        // Performance capsule → opens Monitor view
        Rectangle {
            id: perfCap
            Layout.preferredHeight: 26
            Layout.preferredWidth: perfHover.containsMouse ? 130 : 30
            Behavior on Layout.preferredWidth { NumberAnimation { duration: 160; easing.type: Easing.OutExpo } }
            radius: 8; color: bar.cPanel; clip: true
            MouseArea {
                id: perfHover; anchors.fill: parent; hoverEnabled: true
                onClicked: bar.controlCenterRef.openView("monitor")
            }
            Row {
                anchors.centerIn: parent; spacing: 6
                Text { text: "\uf2db"; color: bar.cInkSoft; font.family: bar.mono; font.pixelSize: 12 }
                Text {
                    text: "perf"; color: bar.cInkSoft; font.family: bar.mono; font.pixelSize: 11
                    width: perfHover.containsMouse ? implicitWidth : 0
                    clip: true
                    opacity: perfHover.containsMouse ? 1 : 0
                    Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutExpo } }
                    Behavior on opacity { NumberAnimation { duration: 120 } }
                }
            }
        }


        // Status + control-center capsule → opens Home
        Rectangle {
            Layout.preferredHeight: 26
            Layout.preferredWidth: statusRow.implicitWidth + 20
            radius: 8; color: bar.cPanel
            Row {
                id: statusRow
                anchors.centerIn: parent
                spacing: 12
                Text { text: "\uf1eb"; color: bar.cInkSoft; font.family: bar.mono; font.pixelSize: 12 }
                Text { text: "\uf028"; color: bar.cInkSoft; font.family: bar.mono; font.pixelSize: 12 }
                Text { text: "\uf240"; color: bar.cInkSoft; font.family: bar.mono; font.pixelSize: 12 }
                Rectangle {
                    width: 22; height: 20; radius: 6; color: "transparent"
                    Text { anchors.centerIn: parent; text: "\uf013"; color: bar.cHot; font.family: bar.mono; font.pixelSize: 13 }
                    MouseArea { anchors.fill: parent; onClicked: bar.controlCenterRef.openView("home") }
                }
            }
        }
    }

    Process { id: wsProc; function exec(cmd) { command = cmd; running = true } }
}
