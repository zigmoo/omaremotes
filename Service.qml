import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons as Commons
import qs.Ui as Ui

Item {
  id: root
  readonly property string moduleName: "moo.omaremotes"
  property QtObject bar: null
  property Item anchorItem: null
  property bool menuOpen: false
  property var widgetAnchors: []
  function close() { menuOpen = false }
  function attach(item, host) {
    widgetAnchors = widgetAnchors.filter(function(e) { return e.item && e.item !== item }).concat([{item:item, bar:host}])
    if (!menuOpen) { anchorItem = item; bar = host }
  }
  function detach(item) { widgetAnchors = widgetAnchors.filter(function(e) { return e.item && e.item !== item }) }
  function showFor(item, host) {
    anchorItem = item; bar = host; menuOpen = true
    if (bar) bar.requestPopout(root)
    machines.refresh()
  }
  function show() { if (widgetAnchors.length) showFor(widgetAnchors[0].item, widgetAnchors[0].bar) }
  IpcHandler {
    target: root.moduleName
    function show(): void { root.show() }
    function hide(): void { root.close() }
  }
  Ui.KeyboardPanel {
    bar: root.bar
    owner: root
    anchorItem: root.anchorItem
    open: root.menuOpen
    focusTarget: machines.focusTarget
    contentWidth: fittedContentWidth(Commons.Style.space(590))
    contentHeight: fittedContentHeight(Commons.Style.space(620))
    MachinePanel { id: machines; anchors.fill: parent; onLaunched: root.close() }
  }
}
