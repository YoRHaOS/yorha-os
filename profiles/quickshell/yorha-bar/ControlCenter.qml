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
    onViewChanged: if (view === "settings") settingsProc.running = true

    // ---- live palette (YorhaTheme.qml ← ~/.config/yorha/colors.css) ---------
    readonly property color cSand:      YorhaTheme.sand       // panel base
    readonly property color cSandDeep:  YorhaTheme.sandDeep   // rail (recessed)
    readonly property color cPanel:     YorhaTheme.panel      // card fill (lifted)
    readonly property color cInk:       YorhaTheme.ink        // primary text
    readonly property color cInkSoft:   YorhaTheme.inkSoft    // secondary text
    readonly property color cInkFaint:  YorhaTheme.inkFaint   // muted text
    readonly property color cRule:      YorhaTheme.rule       // hairlines
    readonly property color cHot:       YorhaTheme.hot        // accent
    readonly property color cActiveText:YorhaTheme.sand       // label on accent fill
    readonly property string mono: "JetBrainsMono Nerd Font"

    // ---- quick toggles (Home tiles) ---------------------------------------
    // State comes from toggles-status.sh, so tiles show what the system is
    // actually doing. A click flips the tile instantly (optimistic), runs the
    // real command, then re-reads state to confirm.
    property bool wifiOn: true
    property bool btOn: false
    property bool caffeineOn: false             // owned by the bar: an idle inhibitor it holds open
    property bool nightLightOn: false
    property bool dndOn: false
    property string powerProfile: ""            // power-saver | balanced | performance
    readonly property bool saverOn: powerProfile === "power-saver"
    readonly property string togglesScript: Qt.resolvedUrl("toggles-status.sh").toString().replace(/^file:\/\//, "")

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
    property var ramHist: []
    property var gpuHist: []
    property var diskHist: []
    property var netHist: []
    property var tempHist: []
    property real gpuNow: 0
    property real gpuTemp: 0
    property real diskNow: 0          // MB/s (read+write)
    property var _prevDisk: null
    function pushHist(arr, v) { var h = arr.slice(); h.push(v); while (h.length > 60) h.shift(); return h }

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

    // ---- wifi (nmcli via wifi-status.sh) ---------------------------------
    property var networks: []        // [{inuse, signal, security, ssid}]
    property var savedSsids: ({})    // ssid -> true (known profiles)
    property string wifiExpanded: "" // ssid whose inline password field is open
    property string _wifiSig: ""
    readonly property string wifiScript: Qt.resolvedUrl("wifi-status.sh").toString().replace(/^file:\/\//, "")

    // ---- bluetooth (bluetoothctl via bt-status.sh) -----------------------
    property bool btPower: false
    property var btDevices: []       // [{mac, paired, connected, name}]
    property string _btSig: ""
    readonly property string btScript: Qt.resolvedUrl("bt-status.sh").toString().replace(/^file:\/\//, "")

    // ---- settings (panel.conf via yorha-settings.sh) --------------------
    property var settings: ({})      // KEY -> value
    readonly property string settingsScript: Qt.resolvedUrl("yorha-settings.sh").toString().replace(/^file:\/\//, "")
    readonly property var autostartItems: ["dunst", "hypridle", "hyprpaper"]
    function autostartOn(name) { return root.settings["AUTOSTART_" + name] !== "0" }   // default on
    function setKV(k, v) { settingsSet.set(k, v); var m = Object.assign({}, root.settings); m[k] = v; root.settings = m }

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
        gpuProc.running = true; diskProc.running = true
        togglesProc.running = true
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
        stdout: SplitParser { onRead: d => { const v = parseFloat(d.trim()); if (!isNaN(v)) { root.tempNow = v; root.tempHist = root.pushHist(root.tempHist, v) } } }
    }
    Process {
        id: memProc; command: ["sh","-c","free -m | awk '/^Mem:/ {print $3, $2}'"]
        stdout: SplitParser {
            onRead: d => { const p = d.trim().split(/\s+/); if (p.length>=2){ root.memUsed=+p[0]; root.memTotal=+p[1]; root.ramHist = root.pushHist(root.ramHist, root.memTotal ? root.memUsed/root.memTotal*100 : 0) } }
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
                        root.netHist = root.pushHist(root.netHist, root.netDown + root.netUp)
                    }
                }
                root._prevNet = { rx: rx, tx: tx, t: now }
            }
        }
    }

    // GPU (nvidia-smi): utilization % + temperature.
    Process {
        id: gpuProc
        command: ["sh","-c","nvidia-smi --query-gpu=utilization.gpu,temperature.gpu --format=csv,noheader,nounits 2>/dev/null | head -1"]
        stdout: SplitParser {
            onRead: d => {
                const p = d.trim().split(/,\s*/)
                if (p.length >= 1 && p[0] !== "") { root.gpuNow = parseFloat(p[0]) || 0; root.gpuHist = root.pushHist(root.gpuHist, root.gpuNow) }
                if (p.length >= 2) root.gpuTemp = parseFloat(p[1]) || 0
            }
        }
    }
    // Disk I/O: /proc/diskstats sectors read+written (fields 6 & 10), physical
    // disks only, delta / interval -> MB/s (sector = 512 bytes).
    Process {
        id: diskProc; command: ["sh","-c","cat /proc/diskstats"]
        stdout: StdioCollector {
            onStreamFinished: {
                let rd = 0, wr = 0
                for (const line of text.split("\n")) {
                    const p = line.trim().split(/\s+/)
                    if (p.length < 10) continue
                    const dev = p[2]
                    // whole disks only (avoids double-counting partitions incl. nvme pN)
                    if (!/^(sd[a-z]+|vd[a-z]+|hd[a-z]+|nvme[0-9]+n[0-9]+|mmcblk[0-9]+)$/.test(dev)) continue
                    rd += Number(p[5]) || 0; wr += Number(p[9]) || 0
                }
                const now = Date.now()
                if (root._prevDisk) {
                    const dts = (now - root._prevDisk.t) / 1000
                    if (dts > 0) {
                        root.diskNow = Math.max(0, ((rd - root._prevDisk.rd) + (wr - root._prevDisk.wr)) * 512 / 1e6 / dts)
                        root.diskHist = root.pushHist(root.diskHist, root.diskNow)
                    }
                }
                root._prevDisk = { rd: rd, wr: wr, t: now }
            }
        }
    }
    // ---- quick toggles: state + actions ----------------------------------
    Process { id: togglesProc; command: ["sh", root.togglesScript]
        stdout: StdioCollector { onStreamFinished: root.parseToggles(text) } }
    Timer { id: togglesFollow; interval: 800; repeat: false; onTriggered: togglesProc.running = true }
    function parseToggles(text) {
        for (const line of text.split("\n")) {
            const f = line.split("\t")
            if (f.length < 2) continue
            if (f[0] === "WIFI")         root.wifiOn = f[1] === "1"
            else if (f[0] === "BT")      root.btOn = f[1] === "1"
            else if (f[0] === "DND")     root.dndOn = f[1] === "1"
            else if (f[0] === "NIGHT")   root.nightLightOn = f[1] === "1"
            else if (f[0] === "PROFILE") root.powerProfile = f[1].trim()
        }
    }
    // Caffeine: while this process runs, systemd holds an idle inhibitor and
    // hypridle won't dim/lock/suspend. Turning the tile off ends the process.
    Process {
        running: root.caffeineOn
        command: ["systemd-inhibit", "--what=idle", "--who=YoRHa OS", "--why=Caffeine", "sleep", "infinity"]
    }
    function quickToggle(k) {
        // execDetached = fire-and-forget, so a slow command can never swallow
        // the next click (the old reused-Process pattern could).
        switch (k) {
        case "wifi":
            root.wifiOn = !root.wifiOn
            Quickshell.execDetached(["nmcli", "radio", "wifi", root.wifiOn ? "on" : "off"]); break
        case "bt":
            root.btOn = !root.btOn
            Quickshell.execDetached(["sh", "-c", root.btOn
                ? "rfkill unblock bluetooth; bluetoothctl power on"
                : "bluetoothctl power off"]); break
        case "caf":
            root.caffeineOn = !root.caffeineOn; return   // no system state to re-read
        case "night":
            root.nightLightOn = !root.nightLightOn
            Quickshell.execDetached(root.nightLightOn ? ["hyprsunset", "-t", "4000"] : ["pkill", "-x", "hyprsunset"]); break
        case "dnd":
            root.dndOn = !root.dndOn
            Quickshell.execDetached(["dunstctl", "set-paused", root.dndOn ? "true" : "false"]); break
        case "saver":
            root.powerProfile = root.saverOn ? "balanced" : "power-saver"
            Quickshell.execDetached(["powerprofilesctl", "set", root.powerProfile]); break
        }
        togglesFollow.restart()
    }

    // ---- session actions (header buttons) ----------------------------------
    // Power off needs two clicks within 3s — one stray click shouldn't kill the machine.
    property bool powerArmed: false
    Timer { id: powerDisarm; interval: 3000; onTriggered: root.powerArmed = false }
    function sessionAction(act) {
        if (act === "close") root.opened = false
        else if (act === "settings") root.view = "settings"
        else if (act === "lock") { root.opened = false; Quickshell.execDetached(["hyprlock"]) }
        else if (act === "power") {
            if (root.powerArmed) Quickshell.execDetached(["systemctl", "poweroff"])
            else { root.powerArmed = true; powerDisarm.restart() }
        }
    }
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


    // Wifi model + control. wifiConn is reusable for connect/password submit.
    Process { id: wifiProc; command: ["sh", root.wifiScript]
        stdout: StdioCollector { onStreamFinished: root.parseWifi(text) } }
    Process { id: wifiConn; function run(a){ command = ["nmcli"].concat(a); running = true } }
    Process { id: wifiRescan; command: ["nmcli","device","wifi","rescan"] }
    Timer { id: wifiFollow; interval: 2000; repeat: false; onTriggered: wifiProc.running = true }
    Timer { interval: 6000; running: root.opened && root.view === "network"; repeat: true; triggeredOnStart: true; onTriggered: wifiProc.running = true }
    function parseWifi(text) {
        const nets = [], saved = {}
        for (const line of text.split("\n")) {
            if (!line) continue
            const f = line.split("\t")
            if (f[0] === "NET" && f.length >= 5) nets.push({ inuse: f[1] === "1", signal: parseInt(f[2]) || 0, security: f[3], ssid: f[4] })
            else if (f[0] === "SAVED" && f.length >= 2) saved[f[1]] = true
        }
        nets.sort((a, b) => (b.inuse ? 1 : 0) - (a.inuse ? 1 : 0) || b.signal - a.signal)
        const sig = JSON.stringify([nets, saved])
        if (sig === root._wifiSig) return
        root._wifiSig = sig; root.networks = nets; root.savedSsids = saved
    }
    function wifiClick(net) {
        if (net.inuse) return
        if (net.security === "" || root.savedSsids[net.ssid]) { wifiConn.run(["device","wifi","connect", net.ssid]); root.wifiExpanded = "" }
        else root.wifiExpanded = (root.wifiExpanded === net.ssid) ? "" : net.ssid
    }

    // Bluetooth model + control.
    Process { id: btProc; command: ["sh", root.btScript]
        stdout: StdioCollector { onStreamFinished: root.parseBt(text) } }
    Process { id: btCtl; function run(a){ command = ["bluetoothctl"].concat(a); running = true } }
    Process { id: btPairConn; function run(mac){ command = ["sh","-c","bluetoothctl pair '" + mac + "' ; bluetoothctl connect '" + mac + "'"]; running = true } }
    Timer { id: btFollow;     interval: 1500; repeat: false; onTriggered: btProc.running = true }
    Timer { id: btScanFollow; interval: 9000; repeat: false; onTriggered: btProc.running = true }
    Timer { interval: 4000; running: root.opened && root.view === "bluetooth"; repeat: true; triggeredOnStart: true; onTriggered: btProc.running = true }
    function parseBt(text) {
        const devs = []; let power = false
        for (const line of text.split("\n")) {
            if (!line) continue
            const f = line.split("\t")
            if (f[0] === "POWER") power = f[1] === "1"
            else if (f[0] === "DEV" && f.length >= 5) devs.push({ mac: f[1], paired: f[2] === "1", connected: f[3] === "1", name: f[4] })
        }
        devs.sort((a, b) => (b.connected ? 1 : 0) - (a.connected ? 1 : 0) || (b.paired ? 1 : 0) - (a.paired ? 1 : 0))
        const sig = JSON.stringify([power, devs])
        if (sig === root._btSig) return
        root._btSig = sig; root.btPower = power; root.btDevices = devs
    }
    function btClick(d) {
        if (d.connected) btCtl.run(["disconnect", d.mac])
        else if (d.paired) btCtl.run(["connect", d.mac])
        else btPairConn.run(d.mac)
        btFollow.restart()
    }

    // Settings store + theme switcher (reuses PR #9 scripts/set-theme.sh; theme
    // logic is NOT reimplemented here).
    Process { id: settingsProc; command: ["sh", root.settingsScript, "dump"]
        stdout: StdioCollector { onStreamFinished: root.parseSettings(text) } }
    Process { id: settingsSet; function set(k, v){ command = ["sh", root.settingsScript, "set", k, v]; running = true } }
    Process { id: themeCmd; function apply(mode){ command = ["sh","-c","\"${YORHA_REPO:-$HOME/yorha-os}/scripts/set-theme.sh\" " + mode]; running = true } }
    function parseSettings(text) {
        const m = {}
        for (const line of text.split("\n")) { const i = line.indexOf("="); if (i > 0) m[line.slice(0, i)] = line.slice(i + 1) }
        root.settings = m
    }
    Timer { interval: 1500; running: root.opened; repeat: true; onTriggered: root.refreshAll() }

    // ===================== reusable inline components ====================
    // Small metric card: eyebrow title, filled-area sparkline, current value.
    component MetricTile: Card {
        property string title: ""
        property string valueText: ""
        property var history: []
        property real maxV: 100                 // <= 0 means auto-scale to the data
        ColumnLayout {
            anchors.fill: parent; anchors.margins: 8; spacing: 2
            Text { text: title; color: root.cInkFaint; font.family: root.mono; font.pixelSize: 8; font.letterSpacing: 1; font.capitalization: Font.AllUppercase }
            Canvas {
                Layout.fillWidth: true; Layout.fillHeight: true; antialiasing: true
                property var h: history
                onHChanged: requestPaint()
                onPaint: {
                    const ctx = getContext("2d"); ctx.reset()
                    const w = width, ht = height
                    if (!h || h.length < 2) return
                    let mv = maxV
                    if (mv <= 0) { mv = 1; for (var k = 0; k < h.length; k++) if (h[k] > mv) mv = h[k] }
                    const n = h.length, dx = w / 59
                    const yAt = v => ht - Math.max(0, Math.min(1, v / mv)) * ht
                    ctx.beginPath(); ctx.moveTo(0, ht)
                    for (var i = 0; i < n; i++) ctx.lineTo(i * dx, yAt(h[i]))
                    ctx.lineTo((n - 1) * dx, ht); ctx.closePath()
                    ctx.fillStyle = Qt.rgba(0.733, 0.357, 0.196, 0.18); ctx.fill()
                    ctx.beginPath(); ctx.moveTo(0, yAt(h[0]))
                    for (var j = 1; j < n; j++) ctx.lineTo(j * dx, yAt(h[j]))
                    ctx.lineWidth = 1.5; ctx.strokeStyle = root.cHot; ctx.stroke()
                }
            }
            Text { text: valueText; color: root.cInk; font.family: root.mono; font.pixelSize: 12; font.bold: true }
        }
    }
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
                        Text {
                            visible: root.powerArmed
                            anchors.verticalCenter: parent.verticalCenter
                            text: "CLICK AGAIN TO SHUT DOWN"
                            font.family: root.mono; font.pixelSize: 9; font.letterSpacing: 1
                            color: root.cHot
                        }
                        Repeater {
                            model: [
                                { g: "\uf013", act: "settings" },
                                { g: "\uf023", act: "lock" },
                                { g: "\uf011", act: "power" },
                                { g: "\uf00d", act: "close" }
                            ]
                            delegate: Text {
                                text: modelData.g; font.family: root.mono; font.pixelSize: 13
                                color: btnMa.containsMouse || (modelData.act === "power" && root.powerArmed)
                                       ? root.cHot : root.cInkFaint
                                MouseArea {
                                    id: btnMa
                                    anchors.fill: parent; anchors.margins: -4; hoverEnabled: true
                                    onClicked: root.sessionAction(modelData.act)
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
                                            { k:"saver", g:"\uf06c", l:"Saver" }
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
                                                    case "saver": return root.saverOn
                                                }
                                                return false
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
                                                onClicked: root.quickToggle(modelData.k)
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
                            anchors.fill: parent; spacing: 10
                            opacity: root.view === "monitor" ? 1 : 0
                            visible: opacity > 0.01
                            Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutExpo } }
                            Eyebrow { text: "Performance" }
                            GridLayout {
                                Layout.fillWidth: true; Layout.fillHeight: true
                                columns: 2; rowSpacing: 10; columnSpacing: 10
                                MetricTile { Layout.fillWidth: true; Layout.fillHeight: true; title: "CPU";  history: root.cpuHist;  maxV: 100; valueText: Math.round(root.cpuNow) + "%" }
                                MetricTile { Layout.fillWidth: true; Layout.fillHeight: true; title: "RAM";  history: root.ramHist;  maxV: 100; valueText: root.memTotal ? Math.round(root.memUsed / root.memTotal * 100) + "%" : "-" }
                                MetricTile { Layout.fillWidth: true; Layout.fillHeight: true; title: "GPU";  history: root.gpuHist;  maxV: 100; valueText: Math.round(root.gpuNow) + "%" }
                                MetricTile { Layout.fillWidth: true; Layout.fillHeight: true; title: "DISK"; history: root.diskHist; maxV: 0;   valueText: root.diskNow.toFixed(1) + " M/s" }
                                MetricTile { Layout.fillWidth: true; Layout.fillHeight: true; title: "NET";  history: root.netHist;  maxV: 0;   valueText: "\u2193" + root.netDown.toFixed(0) + " \u2191" + root.netUp.toFixed(0) }
                                MetricTile { Layout.fillWidth: true; Layout.fillHeight: true; title: "TEMP"; history: root.tempHist; maxV: 100; valueText: root.tempNow ? Math.round(root.tempNow) + "\u00b0C" : "-" }
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

                        // ---- NETWORK (WiFi) ----
                        ColumnLayout {
                            anchors.fill: parent; spacing: 10
                            opacity: root.view === "network" ? 1 : 0
                            visible: opacity > 0.01
                            Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutExpo } }

                            RowLayout {
                                Layout.fillWidth: true; spacing: 8
                                Eyebrow { Layout.fillWidth: true; text: "Networks" }
                                Text { text: "\uf021"; font.family: root.mono; font.pixelSize: 12; color: rescanMa.containsMouse ? root.cHot : root.cInkFaint
                                       MouseArea { id: rescanMa; anchors.fill: parent; anchors.margins: -6; hoverEnabled: true; onClicked: { wifiRescan.running = true; wifiFollow.restart() } } }
                            }
                            Hairline { Layout.fillWidth: true }

                            Flickable {
                                Layout.fillWidth: true; Layout.fillHeight: true
                                contentWidth: width; contentHeight: netCol.implicitHeight
                                clip: true; boundsBehavior: Flickable.StopAtBounds
                                ColumnLayout {
                                    id: netCol
                                    width: parent.width; spacing: 6
                                    Text { visible: root.networks.length === 0; text: "scanning…"; color: root.cInkFaint; font.family: root.mono; font.pixelSize: 11 }
                                    Repeater {
                                        model: root.networks
                                        delegate: ColumnLayout {
                                            Layout.fillWidth: true; spacing: 4
                                            Item {
                                                Layout.fillWidth: true; Layout.preferredHeight: 32
                                                RowLayout {
                                                    anchors.fill: parent; spacing: 8
                                                    Text { text: "\uf1eb"; font.family: root.mono; font.pixelSize: 13; color: modelData.inuse ? root.cHot : root.cInkSoft; opacity: 0.35 + 0.65 * (modelData.signal / 100) }
                                                    ColumnLayout {
                                                        Layout.fillWidth: true; spacing: 0
                                                        Text { Layout.fillWidth: true; text: modelData.ssid; elide: Text.ElideRight; color: modelData.inuse ? root.cInk : root.cInkSoft; font.family: root.mono; font.pixelSize: 12; font.bold: modelData.inuse }
                                                        Text { visible: modelData.inuse; text: "connected"; color: root.cInkFaint; font.family: root.mono; font.pixelSize: 9 }
                                                    }
                                                    Text { visible: modelData.security !== ""; text: "\uf023"; font.family: root.mono; font.pixelSize: 10; color: root.cInkFaint }
                                                    Text { text: modelData.signal + "%"; font.family: root.mono; font.pixelSize: 10; color: root.cInkFaint }
                                                }
                                                MouseArea { anchors.fill: parent; onClicked: root.wifiClick(modelData) }
                                            }
                                            RowLayout {
                                                Layout.fillWidth: true; visible: root.wifiExpanded === modelData.ssid; spacing: 6
                                                TextField {
                                                    id: pwField; Layout.fillWidth: true
                                                    echoMode: TextInput.Password; placeholderText: "password"
                                                    font.family: root.mono; font.pixelSize: 11
                                                    onAccepted: { wifiConn.run(["device","wifi","connect", modelData.ssid, "password", text]); root.wifiExpanded = "" }
                                                }
                                                Text { text: "\uf061"; font.family: root.mono; font.pixelSize: 13; color: root.cHot
                                                       MouseArea { anchors.fill: parent; anchors.margins: -4; onClicked: { wifiConn.run(["device","wifi","connect", modelData.ssid, "password", pwField.text]); root.wifiExpanded = "" } } }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // ---- BLUETOOTH ----
                        ColumnLayout {
                            anchors.fill: parent; spacing: 10
                            opacity: root.view === "bluetooth" ? 1 : 0
                            visible: opacity > 0.01
                            Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutExpo } }

                            RowLayout {
                                Layout.fillWidth: true; spacing: 8
                                Eyebrow { Layout.fillWidth: true; text: "Bluetooth" }
                                Rectangle {
                                    Layout.preferredWidth: 46; Layout.preferredHeight: 20; radius: 10
                                    color: root.btPower ? root.cHot : "transparent"
                                    border.color: root.cRule; border.width: root.btPower ? 0 : 1
                                    Behavior on color { ColorAnimation { duration: 180 } }
                                    Text { anchors.centerIn: parent; text: root.btPower ? "ON" : "OFF"; font.family: root.mono; font.pixelSize: 9; color: root.btPower ? root.cActiveText : root.cInkFaint }
                                    MouseArea { anchors.fill: parent; onClicked: { btCtl.run(["power", root.btPower ? "off" : "on"]); btFollow.restart() } }
                                }
                                Text { text: "\uf021"; font.family: root.mono; font.pixelSize: 12; color: btScanMa.containsMouse ? root.cHot : root.cInkFaint
                                       MouseArea { id: btScanMa; anchors.fill: parent; anchors.margins: -6; hoverEnabled: true; onClicked: { btCtl.run(["--timeout","8","scan","on"]); btScanFollow.restart() } } }
                            }
                            Hairline { Layout.fillWidth: true }

                            Flickable {
                                Layout.fillWidth: true; Layout.fillHeight: true
                                contentWidth: width; contentHeight: btCol.implicitHeight
                                clip: true; boundsBehavior: Flickable.StopAtBounds
                                ColumnLayout {
                                    id: btCol
                                    width: parent.width; spacing: 6
                                    Text { visible: !root.btPower; text: "bluetooth off"; color: root.cInkFaint; font.family: root.mono; font.pixelSize: 11 }
                                    Text { visible: root.btPower && root.btDevices.length === 0; text: "no devices — press scan"; color: root.cInkFaint; font.family: root.mono; font.pixelSize: 11 }
                                    Repeater {
                                        model: root.btDevices
                                        delegate: Item {
                                            Layout.fillWidth: true; Layout.preferredHeight: 32
                                            RowLayout {
                                                anchors.fill: parent; spacing: 8
                                                Text { text: "\uf294"; font.family: root.mono; font.pixelSize: 13; color: modelData.connected ? root.cHot : root.cInkSoft }
                                                ColumnLayout {
                                                    Layout.fillWidth: true; spacing: 0
                                                    Text { Layout.fillWidth: true; text: modelData.name; elide: Text.ElideRight; color: modelData.connected ? root.cInk : root.cInkSoft; font.family: root.mono; font.pixelSize: 12; font.bold: modelData.connected }
                                                    Text { visible: modelData.connected || modelData.paired; text: modelData.connected ? "connected" : "paired"; color: root.cInkFaint; font.family: root.mono; font.pixelSize: 9 }
                                                }
                                            }
                                            MouseArea { anchors.fill: parent; onClicked: root.btClick(modelData) }
                                        }
                                    }
                                }
                            }
                        }

                        // ---- SETTINGS ----
                        ColumnLayout {
                            anchors.fill: parent; spacing: 12
                            opacity: root.view === "settings" ? 1 : 0
                            visible: opacity > 0.01
                            Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutExpo } }

                            Eyebrow { text: "Theme" }
                            RowLayout {
                                Layout.fillWidth: true; spacing: 8
                                Repeater {
                                    model: [{ m: "light", l: "Light" }, { m: "dark", l: "Dark" }]
                                    delegate: Rectangle {
                                        Layout.fillWidth: true; Layout.preferredHeight: 30; radius: 8
                                        color: "transparent"; border.color: root.cRule; border.width: 1
                                        Text { anchors.centerIn: parent; text: modelData.l; font.family: root.mono; font.pixelSize: 11; color: root.cInkSoft }
                                        MouseArea { anchors.fill: parent; onClicked: themeCmd.apply(modelData.m) }
                                    }
                                }
                            }

                            Hairline { Layout.fillWidth: true }

                            Eyebrow { text: "Autostart" }
                            Repeater {
                                model: root.autostartItems
                                delegate: RowLayout {
                                    Layout.fillWidth: true; spacing: 8
                                    Text { Layout.fillWidth: true; text: modelData; color: root.cInkSoft; font.family: root.mono; font.pixelSize: 12 }
                                    Rectangle {
                                        Layout.preferredWidth: 46; Layout.preferredHeight: 20; radius: 10
                                        property bool on: root.autostartOn(modelData)
                                        color: on ? root.cHot : "transparent"; border.color: root.cRule; border.width: on ? 0 : 1
                                        Behavior on color { ColorAnimation { duration: 160 } }
                                        Text { anchors.centerIn: parent; text: parent.on ? "ON" : "OFF"; font.family: root.mono; font.pixelSize: 9; color: parent.on ? root.cActiveText : root.cInkFaint }
                                        MouseArea { anchors.fill: parent; onClicked: root.setKV("AUTOSTART_" + modelData, root.autostartOn(modelData) ? "0" : "1") }
                                    }
                                }
                            }
                            Text { text: "honored by yorha-autostart.sh (add it as one exec-once)"; color: root.cInkFaint; font.family: root.mono; font.pixelSize: 9 }

                            Hairline { Layout.fillWidth: true }

                            Eyebrow { text: "Bar Position" }
                            RowLayout {
                                Layout.fillWidth: true; spacing: 8
                                Repeater {
                                    model: [{ v: "left", l: "Left" }, { v: "right", l: "Right" }]
                                    delegate: Rectangle {
                                        Layout.fillWidth: true; Layout.preferredHeight: 30; radius: 8
                                        property bool sel: (root.settings["BAR_POS"] || "right") === modelData.v
                                        color: sel ? root.cHot : "transparent"; border.color: root.cRule; border.width: sel ? 0 : 1
                                        Text { anchors.centerIn: parent; text: modelData.l; font.family: root.mono; font.pixelSize: 11; color: parent.sel ? root.cActiveText : root.cInkSoft }
                                        MouseArea { anchors.fill: parent; onClicked: root.setKV("BAR_POS", modelData.v) }
                                    }
                                }
                            }
                            Text { text: "bar position applies on next restart"; color: root.cInkFaint; font.family: root.mono; font.pixelSize: 9 }

                            Item { Layout.fillHeight: true }
                        }

                        // ---- NETWORK / BLUETOOTH / NOTIFY (minimal real views) ----
                        Repeater {
                            model: [
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
                property color lineColor: root.cInk          // repaint when the theme flips
                onLineColorChanged: requestPaint()
                onPaint: {
                    const ctx = getContext("2d"); ctx.reset()
                    ctx.strokeStyle = root.cInk; ctx.lineWidth = 1
                    for (let y = 0.5; y < height; y += 3) { ctx.beginPath(); ctx.moveTo(0,y); ctx.lineTo(width,y); ctx.stroke() }
                }
                Component.onCompleted: requestPaint()
            }
        }
    }
}
