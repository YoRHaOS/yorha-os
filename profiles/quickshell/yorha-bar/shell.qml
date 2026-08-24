import Quickshell
import QtQuick

ShellRoot {
    // One unified control center replaces the old Calendar/Performance/Media
    // floating panels. Instantiated here with an id and passed into Bar as a
    // property var ref (no cross-file id references).
    ControlCenter { id: controlCenter }

    Bar {
        controlCenterRef: controlCenter
    }
}
