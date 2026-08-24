import Quickshell
import QtQuick

ShellRoot {
    CalendarPanel { id: calendarPanel }
    PerformancePanel { id: perfPanel }
    MediaPanel { id: mediaPanel }
    ControlCenter { id: controlCenter }

    Bar {
        calendarPanelRef: calendarPanel
        perfPanelRef: perfPanel
        mediaPanelRef: mediaPanel
        controlCenterRef: controlCenter
    }
}
