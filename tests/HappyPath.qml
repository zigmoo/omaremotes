import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import qs.Commons as Commons
import "./plugin" as Plugin

ShellRoot {
  Window {
    id: window
    title: "OmaRemotes — interaction check"
    visible: true
    width: 690
    height: 790
    color: Commons.Color.popups.background
    Plugin.MachinePanel { id: panel; anchors.fill: parent; anchors.margins: 20 }
    TestCase {
      name: "OmaRemotesHappyPath"
      when: window.visible
      function test_picker_to_mac_viewer() {
        tryVerify(function() { return panel.machines.length > 0 && !panel.busy }, 15000)
        var search = findChild(panel, "machineSearch")
        mouseClick(search)
        search.text = "moosacrem1promax"
        tryCompare(panel.filtered, "length", 1, 2000)
        var list = findChild(panel, "machineList")
        wait(150)
        var row = list.itemAtIndex(0)
        verify(row !== null)
        mouseClick(row, row.width / 2, row.height / 2)
        compare(panel.selected.machine, "moosacrem1promax")
        var button = findChild(panel, "connectButton")
        verify(button.enabled)
        mouseClick(button)
        tryVerify(function() { return panel.sessionState === "viewer_open" || panel.failed }, 25000)
        verify(!panel.failed, panel.message)
        compare(panel.sessionMachine, "moosacrem1promax")
        compare(panel.sessionState, "viewer_open")
      }
      function cleanupTestCase() {
        console.log("OMAREMOTES HAPPY PATH FAIL COUNT", qtest_results.failCount)
        Qt.callLater(function() { Qt.quit() })
      }
    }
  }
}
