import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

PanelWindow {
    id: bar
    // Top corner, sized to its content (not full monitor width). Side is set from
    // the Settings view (BAR_POS in panel.conf), read once at startup; default right.
    property string barPos: "right"
    anchors.top: true
    anchors.right: bar.barPos !== "left"
    anchors.left: bar.barPos === "left"
    margins.top: 6
    margins.right: 12
    margins.left: 12
    implicitHeight: 40
    implicitWidth: barRow.implicitWidth + 32
    color: "transparent"

    // Bar position preference (Settings view writes it; applied on next start).
    Process {
        id: posProc
        command: ["sh","-c","awk -F= '/^BAR_POS=/{v=$2} END{print v}' \"${XDG_CONFIG_HOME:-$HOME/.config}/yorha/panel.conf\" 2>/dev/null"]
        stdout: SplitParser { onRead: d => { const v = d.trim(); if (v) bar.barPos = v } }
    }
    Component.onCompleted: posProc.running = true

    // Live palette (YorhaTheme.qml ← ~/.config/yorha/colors.css; light by default).
    readonly property color cSand:     YorhaTheme.sand       // bar fill
    readonly property color cPanel:    YorhaTheme.panel      // capsule fill
    readonly property color cInk:      YorhaTheme.ink        // primary text
    readonly property color cInkSoft:  YorhaTheme.inkSoft    // secondary text
    readonly property color cInkFaint: YorhaTheme.inkFaint   // muted text
    readonly property color cRule:     YorhaTheme.rule
    readonly property color cHot:      YorhaTheme.hot        // accent
    readonly property color cActiveText: YorhaTheme.sand     // label on accent
    readonly property string mono: "JetBrainsMono Nerd Font"

    // Event-driven from Hyprland's IPC socket — updates the instant you switch
    // (click, keybind, or anything else), no polling.
    readonly property int activeWorkspace: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1

    // Single unified panel; capsules open it at a specific view.
    property var controlCenterRef

    // Rounded floating capsule (no longer a full-width edge strip)
    Rectangle { anchors.fill: parent; radius: 10; color: bar.cSand }

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
                            onClicked: Hyprland.dispatch("workspace " + (index + 1))
                        }
                    }
                }
            }
        }


        // Media capsule -> opens control center Home (fixed icon width, no expand)
        Rectangle {
            id: mediaCap
            Layout.preferredHeight: 26
            Layout.preferredWidth: 30
            radius: 8; color: bar.cPanel
            Text { anchors.centerIn: parent; text: "\uf001"; color: bar.cInkSoft; font.family: bar.mono; font.pixelSize: 12 }
            MouseArea { anchors.fill: parent; onClicked: bar.controlCenterRef.openView("home") }
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

        // Performance capsule -> opens Monitor view (fixed icon width, no expand)
        Rectangle {
            id: perfCap
            Layout.preferredHeight: 26
            Layout.preferredWidth: 30
            radius: 8; color: bar.cPanel
            Text { anchors.centerIn: parent; text: "\uf2db"; color: bar.cInkSoft; font.family: bar.mono; font.pixelSize: 12 }
            MouseArea { anchors.fill: parent; onClicked: bar.controlCenterRef.openView("monitor") }
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

}
