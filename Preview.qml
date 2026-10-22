import QtQuick
import Quickshell
import qs.Commons as Commons
import "." as Plugin

ShellRoot {
  FloatingWindow {
    title: "OmaRemotes — happy path"
    implicitWidth: 690
    implicitHeight: 790
    color: Commons.Color.popups.background
    Plugin.MachinePanel { anchors.fill: parent; anchors.margins: Commons.Style.space(22) }
  }
}
