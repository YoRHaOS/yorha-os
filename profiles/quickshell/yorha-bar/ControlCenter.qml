// YoRHa OS — unified Control Center panel.
//
// One panel replaces the old CalendarPanel / PerformancePanel / MediaPanel /
// ControlCenter floating rectangles. Left: a vertical icon rail selecting a
// content view. Right: the content pane. Home is the default and holds the card
// grid (profile, media + toggles, clock/weather).
//
// All colors are the LOCKED LIGHT palette from docs/visual-identity.md — no
// wallust dark values. Borderless cards (fill contrast + shadow), corner ticks,
// hairline rules, mono uppercase labels, and a faint scanline overlay per the
// visual identity.
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

PanelWindow {
    id: root
    visible: true
    anchors.top: true
    anchors.right: true          // anchored below the bar, aligned to the right edge
    margins.top: 46
    margins.right: 16
    implicitWidth: 560
    implicitHeight: opened ? 470 : 0
    color: "transparent"

    // ---- state -----------------------------------------------------------
    property bool opened: false
    property string view: "home"                 // active rail view
    function toggle() { opened = !opened; if (opened) refreshAll() }
    function openView(v) { view = v; if (!opened) { opened = true; refreshAll() } }

    // ---- locked light palette (docs/visual-identity.md) ------------------
    readonly property color cSand:      "#d3cdb6"   // panel base
    readonly property color cSandDeep:  "#c6bfa4"   // rail (recessed)
    readonly property color cPanel:     "#dcd7c3"   // card fill (lifted)
    readonly property color cInk:       "#4a4739"   // primary text
    readonly property color cInkSoft:   "#6b6754"   // secondary text
    readonly property color cInkFaint:  "#8d8873"   // muted text
    readonly property color cRule:      "#8d8873"   // hairlines
    readonly property color cHot:       "#bb5b32"   // accent
    readonly property color cActiveText:"#d3cdb6"   // label on accent fill
    readonly property string mono: "JetBrainsMono Nerd Font"

    // ---- toggle state ----------------------------------------------------
    property bool wifiOn: true
    property bool btOn: false
    property bool caffeineOn: false
    property bool nightLightOn: false
    property bool dndOn: false
    property bool perfMode: false               // "Power Profile" tile

    // ---- rolling metric history (Monitor view) ---------------------------
    property var cpuHist: []
    property var _prevCpu: null
    property var _prevNet: null
    property real cpuNow: 0
    property real tempNow: 0
    property real memUsed: 0
    property real memTotal: 0
    property real netDown: 0                     // KB/s
    property real netUp: 0

    // ---- media state -----------------------------------------------------
    property string mStatus: ""
    property string mTitle: ""
    property string mArtist: ""
    property string mArt: ""
    property string mPos: ""
    property string mLen: ""

    // ---- audio (PipeWire via wpctl, parsed by audio-status.sh) -----------
    property var sinks: []           // [{id, def, vol, name}] output devices
    property var sources: []         // input devices
    property var apps: []            // per-application playback streams
    property string _audioSig: ""    // change-guard so idle polls don't churn delegates
    readonly property string audioScript: Qt.resolvedUrl("audio-status.sh").toString().replace(/^file:\/\//, "")
    readonly property var defSink:   { var r = null; for (var i = 0; i < sinks.length;   i++) if (sinks[i].def)   r = sinks[i];   return r }
    readonly property var defSource: { var r = null; for (var i = 0; i < sources.length; i++) if (sources[i].def) r = sources[i]; return r }

    // ---- profile state ---------------------------------------------------
    property string userName: ""
    property string hostName: ""
    property string uptimeStr: ""
    property string osVersion: "YoRHa OS"

    function refreshAll() {
        userProc.running = true; hostProc.running = true
        uptimeProc.running = true; versionProc.running = true
        mediaProc.running = true; statProc.running = true
        tempProc.running = true; memProc.running = true; netProc.running = true
        audioProc.running = true
    }

    Behavior on implicitHeight { NumberAnimation { duration: 260; easing.type: Easing.OutExpo } }

    // ===================== data sources ==================================
    Process { id: userProc;    command: ["whoami"];  stdout: SplitParser { onRead: d => root.userName = d.trim() } }
    Process { id: hostProc;    command: ["hostname"];stdout: SplitParser { onRead: d => root.hostName = d.trim() } }
    Process {
        id: uptimeProc; command: ["sh","-c","uptime -p 2>/dev/null | sed 's/^up //'"]
        stdout: SplitParser { onRead: d => root.uptimeStr = d.trim() }
    }
    Process {
        id: versionProc
        // No YoRHa release file is guaranteed yet; fall back to a stable label.
        command: ["sh","-c","cat /etc/yorha-release 2>/dev/null || (. /etc/os-release 2>/dev/null; echo \"${PRETTY_NAME:-YoRHa OS}\")"]
        stdout: SplitParser { onRead: d => root.osVersion = d.trim() }
    }

    // Media: status | title | artist | artUrl | position | length.
    // playerctl's --format does NOT interpret C escapes like \t, so we use a
    // literal ASCII separator ("|:|") that playerctl passes through verbatim and
    // split on the same literal. --player prefers Spotify but falls back to any
    // active MPRIS player so a bare/first-player mismatch can't hide playback.
    Process {
        id: mediaProc
        command: ["sh","-c",
            "playerctl --player=spotify,%any metadata --format '{{status}}|:|{{title}}|:|{{artist}}|:|{{mpris:artUrl}}|:|{{duration(position)}}|:|{{duration(mpris:length)}}' 2>/dev/null"]
        stdout: SplitParser {
            onRead: d => {
                const p = d.replace(/\n$/,"").split("|:|")
                if (p.length < 3 || (!p[1] && !p[2])) {
                    root.mStatus = ""; root.mTitle = ""; root.mArtist = ""
                    root.mArt = ""; root.mPos = ""; root.mLen = ""
                    return
                }
                root.mStatus = p[0] || ""
                root.mTitle  = p[1] || ""
                root.mArtist = p[2] || ""
                root.mArt    = p[3] || ""     // remote https URL (Spotify CDN) — Image loads directly
                root.mPos    = p[4] || ""
                root.mLen    = p[5] || ""
            }
        }
    }

    // CPU%: /proc/stat first line, delta computed in JS (accurate, non-blocking).
    Process {
        id: statProc; command: ["sh","-c","head -1 /proc/stat"]
        stdout: SplitParser {
            onRead: d => {
                const n = d.trim().split(/\s+/).slice(1).map(Number)
                if (n.length < 4) return
                const idle = n[3] + (n[4] || 0)
                const total = n.reduce((a,b)=>a+b,0)
                if (root._prevCpu) {
                    const dt = total - root._prevCpu.total, di = idle - root._prevCpu.idle
                    if (dt > 0) {
                        root.cpuNow = Math.max(0, Math.min(100, (1 - di/dt) * 100))
                        let h = root.cpuHist.slice(); h.push(root.cpuNow)
                        while (h.length > 60) h.shift()
                        root.cpuHist = h
                        spark.requestPaint()
                    }
                }
                root._prevCpu = { total: total, idle: idle }
            }
        }
    }
    // CPU temp: coretemp-isa-0000 → "Package id 0:" (NOT acpitz / per-core).
    Process {
        id: tempProc
        command: ["sh","-c","sensors coretemp-isa-0000 2>/dev/null | awk '/Package id 0:/ {t=$4; gsub(/[+°C]/,\"\",t); print t; exit}'"]
        stdout: SplitParser { onRead: d => { const v = parseFloat(d.trim()); if (!isNaN(v)) root.tempNow = v } }
    }
    Process {
        id: memProc; command: ["sh","-c","free -m | awk '/^Mem:/ {print $3, $2}'"]
        stdout: SplitParser {
            onRead: d => { const p = d.trim().split(/\s+/); if (p.length>=2){ root.memUsed=+p[0]; root.memTotal=+p[1] } }
        }
    }
    // Net throughput: sum rx/tx across non-lo ifaces, delta / interval.
    Process {
        id: netProc; command: ["sh","-c","cat /proc/net/dev"]
        stdout: StdioCollector {
            onStreamFinished: {
                let rx = 0, tx = 0
                for (const line of text.split("\n")) {
                    const m = line.split(":")
                    if (m.length < 2) continue
                    const iface = m[0].trim()
                    if (iface === "lo" || iface === "") continue
                    const f = m[1].trim().split(/\s+/).map(Number)
                    rx += f[0] || 0; tx += f[8] || 0
                }
                const now = Date.now()
                if (root._prevNet) {
                    const dts = (now - root._prevNet.t) / 1000
                    if (dts > 0) {
                        root.netDown = Math.max(0, (rx - root._prevNet.rx) / 1024 / dts)
                        root.netUp   = Math.max(0, (tx - root._prevNet.tx) / 1024 / dts)
                    }
                }
                root._prevNet = { rx: rx, tx: tx, t: now }
            }
        }
    }

    // Action processes
    Process { id: lockCmd;  command: ["hyprlock"] }
    Process { id: logoutCmd;command: ["hyprctl","dispatch","exit"] }
    Process { id: powerCmd; command: ["systemctl","poweroff"] }
    // Same --player selection as mediaProc so the buttons control the player shown.
    Process { id: mprev; function go(){ command=["playerctl","--player=spotify,%any","previous"]; running=true } }
    Process { id: mplay; function go(){ command=["playerctl","--player=spotify,%any","play-pause"]; running=true } }
    Process { id: mnext; function go(){ command=["playerctl","--player=spotify,%any","next"]; running=true } }

    // Audio model + control. wpVol/wpDef are separate reusable Processes so a rapid
    // slider drag (set-volume) can't clobber a set-default click.
    Process {
        id: audioProc; command: ["sh", root.audioScript]
        stdout: StdioCollector { onStreamFinished: root.parseAudio(text) }
    }
    Process { id: wpVol; function run(a){ command = ["wpctl"].concat(a); running = true } }
    Process { id: wpDef; function run(a){ command = ["wpctl"].concat(a); running = true } }
    function parseAudio(text) {
        const sk = [], sr = [], ap = []
        for (const line of text.split("\n")) {
            if (!line) continue
            const f = line.split("\t")
            if (f.length < 5) continue
            const o = { id: f[1], def: f[2] === "1", vol: parseFloat(f[3]) || 0, name: f[4] }
            if (f[0] === "SINK") sk.push(o)
            else if (f[0] === "SOURCE") sr.push(o)
            else if (f[0] === "APP") ap.push(o)
        }
        const sig = JSON.stringify([sk, sr, ap])
        if (sig === root._audioSig) return          // unchanged → keep delegates (stable sliders)
        root._audioSig = sig
        root.sinks = sk; root.sources = sr; root.apps = ap
    }

    // Map a PipeWire stream/app name to a Nerd Font glyph for the mixer list.
    function appIcon(name) {
        var n = (name || "").toLowerCase()
        if (n.indexOf("spotify") >= 0) return "\uf1bc"
        if (n.indexOf("firefox") >= 0 || n.indexOf("zen") >= 0) return "\uf269"
        if (n.indexOf("chrom") >= 0) return "\uf268"
        if (n.indexOf("discord") >= 0) return "\uf392"
        if (n.indexOf("vlc") >= 0 || n.indexOf("mpv") >= 0 || n.indexOf("video") >= 0) return "\uf03d"
        if (n.indexOf("webrtc") >= 0 || n.indexOf("voice") >= 0) return "\uf130"
        return "\uf001"
    }

    Timer { interval: 1500; running: root.opened; repeat: true; onTriggered: root.refreshAll() }

    // ===================== reusable inline components ====================
    component Eyebrow: Text {
        color: root.cInkFaint; font.family: root.mono; font.pixelSize: 10
        font.letterSpacing: 2; font.capitalization: Font.AllUppercase
    }
    // implicitHeight (not height) so a Layout reads it as a preferred size rather
    // than fighting a direct height binding → avoids "recursive rearrange".
    component Hairline: Rectangle { implicitHeight: 1; color: root.cRule; opacity: 0.5 }
    // Borderless: separation from fill contrast (cPanel on cSand) + a soft faux
    // shadow built from plain QtQuick Rectangles. This deliberately uses NO effects
    // module (neither QtQuick.Effects/MultiEffect nor Qt5Compat.GraphicalEffects/
    // DropShadow) so it cannot fail to import on whatever Qt6 the machine actually
    // has — the shell already relies on Rectangle/Item/anchors everywhere.
    //
    // Content declared at each usage becomes a child of this Item and paints on top
    // of the opaque surface; the two shadow layers sit behind it and peek out.
    component Card: Item {
        property real radius: 12
        Rectangle {                       // outer, softer shadow
            anchors.fill: parent
            anchors.topMargin: 5; anchors.bottomMargin: -5
            anchors.leftMargin: 2; anchors.rightMargin: 2
            radius: parent.radius + 2; antialiasing: true
            color: Qt.rgba(0.29,0.28,0.22,0.07)
        }
        Rectangle {                       // inner, tighter shadow
            anchors.fill: parent
            anchors.topMargin: 3; anchors.bottomMargin: -3
            radius: parent.radius; antialiasing: true
            color: Qt.rgba(0.29,0.28,0.22,0.13)
        }
        Rectangle {                       // opaque card surface
            anchors.fill: parent
            radius: parent.radius; antialiasing: true
            color: root.cPanel
        }
    }

    // ===================== the panel ====================================
    Item {
        anchors.fill: parent
        clip: true

        Rectangle {
            id: shell
            width: parent.width
            height: 470
            radius: 16
            color: root.cSand
            antialiasing: true
            // slide-down + fade, OutExpo, same easing everywhere
            y: root.opened ? 0 : -24
            opacity: root.opened ? 1 : 0
            Behavior on y       { NumberAnimation { duration: 260; easing.type: Easing.OutExpo } }
            Behavior on opacity { NumberAnimation { duration: 260; easing.type: Easing.OutExpo } }

            RowLayout {
                anchors.fill: parent
                spacing: 0

                // ---------------- left icon rail ------------------------
                Rectangle {
                    Layout.fillHeight: true
                    Layout.preferredWidth: 48
                    color: root.cSandDeep
                    topLeftRadius: 16; bottomLeftRadius: 16

                    Column {
                        anchors.top: parent.top; anchors.topMargin: 14
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 6
                        Repeater {
                            model: [
                                { v: "home",    g: "\uf015" },
                                { v: "audio",   g: "\uf028" },
                                { v: "monitor", g: "\uf2db" },
                                { v: "network", g: "\uf1eb" },
                                { v: "bluetooth", g: "\uf294" },
                                { v: "calendar",g: "\uf073" },
                                { v: "notify",  g: "\uf0f3" }
                            ]
                            delegate: Rectangle {
                                width: 34; height: 34; radius: 9
                                property bool active: root.view === modelData.v
                                color: active ? root.cHot : "transparent"
                                Behavior on color { ColorAnimation { duration: 160; easing.type: Easing.OutExpo } }
                                Text {
                                    anchors.centerIn: parent; text: modelData.g
                                    font.family: root.mono; font.pixelSize: 15
                                    color: parent.active ? root.cActiveText : root.cInkSoft
                                    Behavior on color { ColorAnimation { duration: 160; easing.type: Easing.OutExpo } }
                                }
                                MouseArea { anchors.fill: parent; onClicked: root.view = modelData.v }
                            }
                        }
                    }
                }

                // ---------------- content pane --------------------------
                Item {
                    id: content
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    // top-right window buttons
                    Row {
                        z: 5
                        anchors.top: parent.top; anchors.right: parent.right
                        anchors.topMargin: 12; anchors.rightMargin: 16
                        spacing: 10
                        Repeater {
                            model: [
                                { g: "\uf013", act: "settings" },
                                { g: "\uf011", act: "power" },
                                { g: "\uf00d", act: "close" }
                            ]
                            delegate: Text {
                                text: modelData.g; font.family: root.mono; font.pixelSize: 13
                                color: root.cInkFaint
                                MouseArea {
                                    anchors.fill: parent; anchors.margins: -4; hoverEnabled: true
                                    onEntered: parent.color = root.cHot
                                    onExited: parent.color = root.cInkFaint
                                    onClicked: {
                                        if (modelData.act === "close") root.opened = false
                                        else if (modelData.act === "power") powerCmd.running = true
                                        // "settings" reserved
                                    }
                                }
                            }
                        }
                    }

                    // cross-faded views (all stacked, only active is opaque)
                    Item {
                        anchors.fill: parent
                        anchors.topMargin: 40; anchors.leftMargin: 20
                        anchors.rightMargin: 20; anchors.bottomMargin: 18

                        // ---- HOME ----
                        ColumnLayout {
                            anchors.fill: parent; spacing: 12
                            opacity: root.view === "home" ? 1 : 0
                            visible: opacity > 0.01
                            Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutExpo } }

                            // profile card (full width)
                            Card {
                                Layout.fillWidth: true; Layout.preferredHeight: 74
                                RowLayout {
                                    anchors.fill: parent; anchors.margins: 14; spacing: 14
                                    Rectangle {
                                        Layout.preferredWidth: 46; Layout.preferredHeight: 46
                                        radius: 23; color: root.cSandDeep
                                        border.color: root.cHot; border.width: 2
                                        Text { anchors.centerIn: parent; text: (root.userName[0]||"?").toUpperCase()
                                               font.family: root.mono; font.pixelSize: 18; color: root.cInk }
                                    }
                                    ColumnLayout {
                                        spacing: 2
                                        Text { text: root.userName || "user"; color: root.cInk
                                               font.family: root.mono; font.pixelSize: 15; font.bold: true }
                                        Text { text: (root.userName||"user") + "@" + (root.hostName||"host")
                                               color: root.cInkSoft; font.family: root.mono; font.pixelSize: 11 }
                                        Text { text: "up " + (root.uptimeStr||"—") + "  ·  " + root.osVersion
                                               color: root.cInkFaint; font.family: root.mono; font.pixelSize: 10 }
                                    }
                                    Item { Layout.fillWidth: true }
                                }
                            }

                            // media card + toggle grid
                            RowLayout {
                                Layout.fillWidth: true; Layout.fillHeight: true; spacing: 12

                                // media card (~60%)
                                Card {
                                    Layout.preferredWidth: parent.width * 0.6; Layout.fillHeight: true
                                    RowLayout {
                                        anchors.fill: parent; anchors.margins: 12; spacing: 12
                                        // album art (remote https) with placeholder
                                        Rectangle {
                                            Layout.preferredWidth: 72; Layout.preferredHeight: 72
                                            radius: 8; color: root.cSandDeep; clip: true
                                            Image {
                                                id: art; anchors.fill: parent
                                                source: root.mArt; fillMode: Image.PreserveAspectCrop
                                                asynchronous: true; cache: true
                                                visible: status === Image.Ready
                                            }
                                            Text {   // placeholder when no art / loading / error
                                                anchors.centerIn: parent; text: "\uf001"
                                                font.family: root.mono; font.pixelSize: 22; color: root.cInkFaint
                                                visible: art.status !== Image.Ready
                                            }
                                        }
                                        ColumnLayout {
                                            Layout.fillWidth: true; spacing: 4
                                            Eyebrow { text: "Now Playing" }
                                            Text {
                                                Layout.fillWidth: true
                                                text: root.mTitle || "nothing playing"
                                                color: root.cInk; font.family: root.mono; font.pixelSize: 13; font.bold: true
                                                elide: Text.ElideRight
                                            }
                                            Text {
                                                Layout.fillWidth: true; text: root.mArtist
                                                color: root.cInkSoft; font.family: root.mono; font.pixelSize: 11
                                                elide: Text.ElideRight; visible: text !== ""
                                            }
                                            Text {
                                                text: root.mStatus ? (root.mStatus + " · " + root.mPos + " / " + root.mLen) : ""
                                                color: root.cInkFaint; font.family: root.mono; font.pixelSize: 10
                                                visible: text !== ""
                                            }
                                            Row {
                                                spacing: 18; Layout.topMargin: 2
                                                Text { text: "\uf048"; font.family: root.mono; font.pixelSize: 13; color: root.cInkSoft
                                                       MouseArea { anchors.fill: parent; anchors.margins:-4; onClicked: mprev.go() } }
                                                Text { text: root.mStatus === "Playing" ? "\uf04c" : "\uf04b"
                                                       font.family: root.mono; font.pixelSize: 14; color: root.cHot
                                                       MouseArea { anchors.fill: parent; anchors.margins:-4; onClicked: mplay.go() } }
                                                Text { text: "\uf051"; font.family: root.mono; font.pixelSize: 13; color: root.cInkSoft
                                                       MouseArea { anchors.fill: parent; anchors.margins:-4; onClicked: mnext.go() } }
                                            }
                                        }
                                    }
                                }

                                // toggle grid (~40%): 2 cols × 3 rows
                                GridLayout {
                                    Layout.fillWidth: true; Layout.fillHeight: true
                                    columns: 2; rowSpacing: 8; columnSpacing: 8
                                    Repeater {
                                        model: [
                                            { k:"wifi",  g:"\uf1eb", l:"WiFi" },
                                            { k:"bt",    g:"\uf294", l:"Bluetooth" },
                                            { k:"caf",   g:"\uf0f4", l:"Caffeine" },
                                            { k:"night", g:"\uf186", l:"Night Light" },
                                            { k:"dnd",   g:"\uf1f6", l:"DND" },
                                            { k:"power", g:"\uf0e7", l:"Power" }
                                        ]
                                        delegate: Rectangle {
                                            Layout.fillWidth: true; Layout.fillHeight: true
                                            radius: 12; antialiasing: true
                                            property bool on: {
                                                switch (modelData.k) {
                                                    case "wifi":  return root.wifiOn
                                                    case "bt":    return root.btOn
                                                    case "caf":   return root.caffeineOn
                                                    case "night": return root.nightLightOn
                                                    case "dnd":   return root.dndOn
                                                    case "power": return root.perfMode
                                                }
                                            }
                                            color: on ? root.cHot : root.cPanel
                                            Behavior on color { ColorAnimation { duration: 180; easing.type: Easing.OutExpo } }
                                            Column {
                                                anchors.centerIn: parent; spacing: 3
                                                Text { anchors.horizontalCenter: parent.horizontalCenter
                                                       text: modelData.g; font.family: root.mono; font.pixelSize: 15
                                                       color: parent.parent.on ? root.cActiveText : root.cInkSoft
                                                       Behavior on color { ColorAnimation { duration: 180 } } }
                                                Text { anchors.horizontalCenter: parent.horizontalCenter
                                                       text: modelData.l; font.family: root.mono; font.pixelSize: 8
                                                       font.letterSpacing: 1; font.capitalization: Font.AllUppercase
                                                       color: parent.parent.on ? root.cActiveText : root.cInkFaint
                                                       Behavior on color { ColorAnimation { duration: 180 } } }
                                            }
                                            MouseArea {
                                                anchors.fill: parent
                                                onClicked: {
                                                    switch (modelData.k) {
                                                        case "wifi":  root.wifiOn = !root.wifiOn; break
                                                        case "bt":    root.btOn = !root.btOn; break
                                                        case "caf":   root.caffeineOn = !root.caffeineOn; break
                                                        case "night": root.nightLightOn = !root.nightLightOn; break
                                                        case "dnd":   root.dndOn = !root.dndOn; break
                                                        case "power": root.perfMode = !root.perfMode; break
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            // clock / weather card (full width)
                            Card {
                                Layout.fillWidth: true; Layout.preferredHeight: 64
                                RowLayout {
                                    anchors.fill: parent; anchors.margins: 14; spacing: 16
                                    Text {
                                        id: bigClock; color: root.cInk; font.family: root.mono
                                        font.pixelSize: 30; font.bold: true
                                        function upd(){ text = Qt.formatDateTime(new Date(),"HH:mm") }
                                        Component.onCompleted: upd()
                                        Timer { interval: 1000; running: true; repeat: true; onTriggered: bigClock.upd() }
                                    }
                                    Rectangle { Layout.preferredWidth: 1; Layout.fillHeight: true
                                                Layout.topMargin: 6; Layout.bottomMargin: 6; color: root.cRule; opacity: 0.5 }
                                    ColumnLayout {
                                        spacing: 2
                                        Text { text: Qt.formatDate(new Date(),"dddd, dd MMM"); color: root.cInkSoft
                                               font.family: root.mono; font.pixelSize: 12 }
                                        Text { text: "— weather unavailable"; color: root.cInkFaint
                                               font.family: root.mono; font.pixelSize: 10 }
                                    }
                                    Item { Layout.fillWidth: true }
                                }
                            }
                        }

                        // ---- MONITOR (performance) ----
                        ColumnLayout {
                            anchors.fill: parent; spacing: 12
                            opacity: root.view === "monitor" ? 1 : 0
                            visible: opacity > 0.01
                            Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutExpo } }

                            Eyebrow { text: "Performance" }
                            Card {
                                Layout.fillWidth: true; Layout.fillHeight: true
                                Canvas {
                                    id: spark
                                    anchors.fill: parent; anchors.margins: 12
                                    antialiasing: true
                                    onPaint: {
                                        const ctx = getContext("2d")
                                        ctx.reset()
                                        const h = height, w = width, hist = root.cpuHist
                                        if (hist.length < 2) return
                                        const n = hist.length
                                        const dx = w / 59
                                        const yAt = v => h - (v/100)*h
                                        // filled area
                                        ctx.beginPath(); ctx.moveTo(0, h)
                                        for (let i=0;i<n;i++) ctx.lineTo(i*dx, yAt(hist[i]))
                                        ctx.lineTo((n-1)*dx, h); ctx.closePath()
                                        ctx.fillStyle = Qt.rgba(0.733,0.357,0.196,0.18)   // accent @ ~18%
                                        ctx.fill()
                                        // line
                                        ctx.beginPath(); ctx.moveTo(0, yAt(hist[0]))
                                        for (let i=1;i<n;i++) ctx.lineTo(i*dx, yAt(hist[i]))
                                        ctx.lineWidth = 2; ctx.strokeStyle = root.cHot; ctx.stroke()
                                    }
                                }
                            }
                            Hairline { Layout.fillWidth: true }
                            RowLayout {
                                Layout.fillWidth: true; spacing: 0
                                Repeater {
                                    model: [
                                        { l:"CPU",  v: Math.round(root.cpuNow) + "%" },
                                        { l:"TEMP", v: (root.tempNow ? Math.round(root.tempNow) + "°C" : "—") },
                                        { l:"RAM",  v: (root.memTotal ? Math.round(root.memUsed) + " / " + Math.round(root.memTotal) + "M" : "—") },
                                        { l:"NET",  v: "↓" + root.netDown.toFixed(0) + " ↑" + root.netUp.toFixed(0) + " K/s" }
                                    ]
                                    delegate: ColumnLayout {
                                        Layout.fillWidth: true; spacing: 2
                                        Text { text: modelData.l; color: root.cInkFaint; font.family: root.mono
                                               font.pixelSize: 9; font.letterSpacing: 1; font.capitalization: Font.AllUppercase }
                                        Text { text: modelData.v; color: root.cInk; font.family: root.mono
                                               font.pixelSize: 13; font.bold: true }
                                    }
                                }
                            }
                        }

                        // ---- AUDIO ----
                        ColumnLayout {
                            anchors.fill: parent; spacing: 10
                            opacity: root.view === "audio" ? 1 : 0
                            visible: opacity > 0.01
                            Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutExpo } }

                            Eyebrow { text: "Audio" }

                            // master quick access — tracks the default sink / default source
                            RowLayout {
                                Layout.fillWidth: true; spacing: 12
                                Text { text: "\uf028"; font.family: root.mono; font.pixelSize: 14; color: root.cInkSoft }
                                Slider {
                                    id: masterVol
                                    Layout.fillWidth: true; from: 0; to: 1.5
                                    Component.onCompleted: value = root.defSink ? root.defSink.vol : 1
                                    onMoved: wpVol.run(["set-volume", "@DEFAULT_AUDIO_SINK@", value.toFixed(2)])
                                    Connections { target: root; function onDefSinkChanged(){ if (!masterVol.pressed && root.defSink) masterVol.value = root.defSink.vol } }
                                }
                                Text { text: Math.round(masterVol.value*100) + "%"; color: masterVol.pressed ? root.cHot : root.cInkFaint; font.family: root.mono; font.pixelSize: 10 }
                            }
                            RowLayout {
                                Layout.fillWidth: true; spacing: 12
                                Text { text: "\uf130"; font.family: root.mono; font.pixelSize: 14; color: root.cInkSoft }
                                Slider {
                                    id: masterMic
                                    Layout.fillWidth: true; from: 0; to: 1.5
                                    Component.onCompleted: value = root.defSource ? root.defSource.vol : 1
                                    onMoved: wpVol.run(["set-volume", "@DEFAULT_AUDIO_SOURCE@", value.toFixed(2)])
                                    Connections { target: root; function onDefSourceChanged(){ if (!masterMic.pressed && root.defSource) masterMic.value = root.defSource.vol } }
                                }
                                Text { text: Math.round(masterMic.value*100) + "%"; color: masterMic.pressed ? root.cHot : root.cInkFaint; font.family: root.mono; font.pixelSize: 10 }
                            }

                            Hairline { Layout.fillWidth: true }

                            // per-device + per-app mixer (scrolls when it overflows)
                            Flickable {
                                Layout.fillWidth: true; Layout.fillHeight: true
                                contentWidth: width; contentHeight: mixCol.implicitHeight
                                clip: true; boundsBehavior: Flickable.StopAtBounds
                                ColumnLayout {
                                    id: mixCol
                                    width: parent.width
                                    spacing: 10

                                    Eyebrow { text: "Output Devices" }
                                    Repeater {
                                        model: root.sinks
                                        delegate: RowLayout {
                                            Layout.fillWidth: true; spacing: 8
                                            Rectangle {
                                                Layout.preferredWidth: 12; Layout.preferredHeight: 12; radius: 6
                                                color: modelData.def ? root.cHot : "transparent"
                                                border.color: root.cRule; border.width: modelData.def ? 0 : 1
                                                MouseArea { anchors.fill: parent; anchors.margins: -6; onClicked: wpDef.run(["set-default", modelData.id]) }
                                            }
                                            ColumnLayout {
                                                Layout.fillWidth: true; spacing: 1
                                                RowLayout {
                                                    Layout.fillWidth: true; spacing: 6
                                                    Text { Layout.fillWidth: true; text: modelData.name; elide: Text.ElideRight; color: modelData.def ? root.cInk : root.cInkSoft; font.family: root.mono; font.pixelSize: 11 }
                                                    Text { text: Math.round(sinkSld.value*100) + "%"; color: sinkSld.pressed ? root.cHot : root.cInkFaint; font.family: root.mono; font.pixelSize: 10 }
                                                }
                                                Slider { id: sinkSld; Layout.fillWidth: true; from: 0; to: 1.5; Component.onCompleted: value = modelData.vol; onMoved: wpVol.run(["set-volume", modelData.id, value.toFixed(2)]) }
                                            }
                                        }
                                    }

                                    Eyebrow { text: "Input Devices" }
                                    Repeater {
                                        model: root.sources
                                        delegate: RowLayout {
                                            Layout.fillWidth: true; spacing: 8
                                            Rectangle {
                                                Layout.preferredWidth: 12; Layout.preferredHeight: 12; radius: 6
                                                color: modelData.def ? root.cHot : "transparent"
                                                border.color: root.cRule; border.width: modelData.def ? 0 : 1
                                                MouseArea { anchors.fill: parent; anchors.margins: -6; onClicked: wpDef.run(["set-default", modelData.id]) }
                                            }
                                            ColumnLayout {
                                                Layout.fillWidth: true; spacing: 1
                                                RowLayout {
                                                    Layout.fillWidth: true; spacing: 6
                                                    Text { Layout.fillWidth: true; text: modelData.name; elide: Text.ElideRight; color: modelData.def ? root.cInk : root.cInkSoft; font.family: root.mono; font.pixelSize: 11 }
                                                    Text { text: Math.round(srcSld.value*100) + "%"; color: srcSld.pressed ? root.cHot : root.cInkFaint; font.family: root.mono; font.pixelSize: 10 }
                                                }
                                                Slider { id: srcSld; Layout.fillWidth: true; from: 0; to: 1.5; Component.onCompleted: value = modelData.vol; onMoved: wpVol.run(["set-volume", modelData.id, value.toFixed(2)]) }
                                            }
                                        }
                                    }

                                    Eyebrow { text: "Applications" }
                                    Text { visible: root.apps.length === 0; text: "nothing playing"; color: root.cInkFaint; font.family: root.mono; font.pixelSize: 11 }
                                    Repeater {
                                        model: root.apps
                                        delegate: RowLayout {
                                            Layout.fillWidth: true; spacing: 8
                                            ColumnLayout {
                                                Layout.fillWidth: true; spacing: 1
                                                RowLayout {
                                                    Layout.fillWidth: true; spacing: 6
                                                    Text { text: root.appIcon(modelData.name); color: root.cInkSoft; font.family: root.mono; font.pixelSize: 12 }
                                                    Text { Layout.fillWidth: true; text: modelData.name; elide: Text.ElideRight; color: root.cInkSoft; font.family: root.mono; font.pixelSize: 11 }
                                                    Text { text: Math.round(appSld.value*100) + "%"; color: appSld.pressed ? root.cHot : root.cInkFaint; font.family: root.mono; font.pixelSize: 10 }
                                                }
                                                Slider { id: appSld; Layout.fillWidth: true; from: 0; to: 1.5; Component.onCompleted: value = modelData.vol; onMoved: wpVol.run(["set-volume", modelData.id, value.toFixed(2)]) }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // ---- CALENDAR ----
                        ColumnLayout {
                            anchors.fill: parent; spacing: 6
                            opacity: root.view === "calendar" ? 1 : 0
                            visible: opacity > 0.01
                            Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutExpo } }
                            Eyebrow { text: "Calendar" }
                            Item { Layout.fillHeight: true }
                            Text { Layout.alignment: Qt.AlignHCenter; text: Qt.formatDate(new Date(),"MMMM yyyy")
                                   color: root.cInk; font.family: root.mono; font.pixelSize: 24; font.bold: true }
                            Text { Layout.alignment: Qt.AlignHCenter; text: Qt.formatDate(new Date(),"dddd, dd")
                                   color: root.cInkSoft; font.family: root.mono; font.pixelSize: 13 }
                            Item { Layout.fillHeight: true }
                        }

                        // ---- NETWORK / BLUETOOTH / NOTIFY (minimal real views) ----
                        Repeater {
                            model: [
                                { v:"network",   l:"Network",       note:"Wi-Fi " + (root.wifiOn ? "on" : "off") },
                                { v:"bluetooth", l:"Bluetooth",     note:"Bluetooth " + (root.btOn ? "on" : "off") },
                                { v:"notify",    l:"Notifications", note:"No notifications" }
                            ]
                            delegate: ColumnLayout {
                                anchors.fill: parent; spacing: 10
                                opacity: root.view === modelData.v ? 1 : 0
                                visible: opacity > 0.01
                                Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutExpo } }
                                Eyebrow { text: modelData.l }
                                Hairline { Layout.fillWidth: true }
                                Text { text: modelData.note; color: root.cInkSoft; font.family: root.mono; font.pixelSize: 12 }
                                Item { Layout.fillHeight: true }
                            }
                        }
                    }
                }
            }

            // ---- YoRHa motifs over everything ----
            // corner ticks (thin L brackets, not a full border)
            Repeater {
                model: [ {x:0,y:0,h:0,v:0}, {x:1,y:0,h:1,v:0}, {x:0,y:1,h:0,v:1}, {x:1,y:1,h:1,v:1} ]
                delegate: Item {
                    z: 20; width: 14; height: 14
                    x: modelData.x ? shell.width - width : 0
                    y: modelData.y ? shell.height - height : 0
                    Rectangle { width: 14; height: 2; color: root.cInk
                                anchors.top: modelData.v ? undefined : parent.top
                                anchors.bottom: modelData.v ? parent.bottom : undefined
                                anchors.left: modelData.h ? undefined : parent.left
                                anchors.right: modelData.h ? parent.right : undefined }
                    Rectangle { width: 2; height: 14; color: root.cInk
                                anchors.top: modelData.v ? undefined : parent.top
                                anchors.bottom: modelData.v ? parent.bottom : undefined
                                anchors.left: modelData.h ? undefined : parent.left
                                anchors.right: modelData.h ? parent.right : undefined }
                }
            }

            // faint scanline overlay
            Canvas {
                anchors.fill: parent; z: 15; opacity: 0.05
                onPaint: {
                    const ctx = getContext("2d"); ctx.reset()
                    ctx.strokeStyle = "#4a4739"; ctx.lineWidth = 1
                    for (let y = 0.5; y < height; y += 3) { ctx.beginPath(); ctx.moveTo(0,y); ctx.lineTo(width,y); ctx.stroke() }
                }
                Component.onCompleted: requestPaint()
            }
        }
    }
}
