import QtQuick
import Quickshell
import qs.Ui as Ui

Ui.BarWidget {
  id: root
  moduleName: "moo.omaremotes"
  readonly property var service: bar && bar.shell ? bar.shell.serviceFor(moduleName) : null
  readonly property var hostWindow: icon.QsWindow.window
  implicitWidth: icon.implicitWidth
  implicitHeight: icon.implicitHeight
  function attach() { if (service && hostWindow) service.attach(icon, bar) }
  onServiceChanged: Qt.callLater(attach)
  onBarChanged: Qt.callLater(attach)
  onHostWindowChanged: Qt.callLater(attach)
  Component.onCompleted: Qt.callLater(attach)
  Component.onDestruction: if (service) service.detach(icon)
  Ui.BarIconButton {
    id: icon
    anchors.fill: parent
    bar: root.bar
    text: "󰢹"
    tooltipText: "OmaRemotes"
    active: root.service && root.service.menuOpen
    onPressed: function(button) {
      if (button !== Qt.LeftButton || !root.service) return
      if (root.service.menuOpen) root.service.close()
      else root.service.showFor(icon, root.bar)
    }
  }
}
