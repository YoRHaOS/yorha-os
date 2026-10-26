pragma Singleton
// YoRHa OS — live palette for the whole shell.
//
// Reads the eight-variable contract from ~/.config/yorha/colors.css — the one
// file scripts/set-theme.sh writes — and watches it, so Light/Dark in the
// Settings view repaints the bar and panel immediately, no restart.
// Defaults are the locked LIGHT palette (docs/visual-identity.md), used until
// the file exists or if it can't be parsed.
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: pal

    property color sand:     "#d3cdb6"
    property color sandDeep: "#c6bfa4"
    property color panel:    "#dcd7c3"
    property color ink:      "#4a4739"
    property color inkSoft:  "#6b6754"
    property color inkFaint: "#8d8873"
    property color rule:     "#8d8873"
    property color hot:      "#bb5b32"

    readonly property string path: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/yorha/colors.css"

    function parse(css) {
        const map = {}
        const re = /--([a-z-]+)\s*:\s*(#[0-9a-fA-F]{6})/g
        let m
        while ((m = re.exec(css)) !== null) map[m[1]] = m[2]
        if (map["sand"])      pal.sand     = map["sand"]
        if (map["sand-deep"]) pal.sandDeep = map["sand-deep"]
        if (map["panel"])     pal.panel    = map["panel"]
        if (map["ink"])       pal.ink      = map["ink"]
        if (map["ink-soft"])  pal.inkSoft  = map["ink-soft"]
        if (map["ink-faint"]) pal.inkFaint = map["ink-faint"]
        if (map["rule"])      pal.rule     = map["rule"]
        if (map["hot"])       pal.hot      = map["hot"]
    }

    FileView {
        path: pal.path
        watchChanges: true
        onFileChanged: reload()
        onLoaded: pal.parse(text())
    }
}
