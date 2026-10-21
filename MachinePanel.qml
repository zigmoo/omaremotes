import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import Quickshell
import Quickshell.Io
import qs.Commons as Commons
import qs.Ui as Ui

Item {
  id: root
  implicitWidth: Commons.Style.space(590)
  implicitHeight: Commons.Style.space(620)
  property var machines: []
  property var selected: null
  property string route: "auto"
  property string message: strings.t("ready")
  property bool failed: false
  property bool loading: false
  property string sessionMachine: ""
  property string sessionState: "closed"
  readonly property bool busy: controller.running
  readonly property var filtered: machines.filter(function(m) {
    var query = search.text.toLowerCase().trim()
    return !query || (m.machine + " " + m.label).toLowerCase().indexOf(query) !== -1
  })
  readonly property Item focusTarget: search
  signal launched()
  Translations { id: strings }

  function refresh() { if (!busy) invoke("list", "") }
  function invoke(action, machine) {
    if (busy) return
    controller.action = action
    loading = action === "list"
    failed = false
    if (action === "connect") message = strings.t("starting").arg(machine)
    else if (action === "list") message = strings.t("loading")
    var argv = ["bash", "-lc", "exec oma_remotes_tool \"$@\"", "omaremotes", action]
    if (machine) argv.push(machine)
    if (action === "connect") argv.push("--route", route)
    controller.command = argv
    controller.running = true
  }
  function connectSelected() {
    if (selected && !selected.local) invoke("connect", selected.machine)
  }
  Component.onCompleted: refresh()

  Process {
    id: controller
    property string action: ""
    stdout: StdioCollector { id: output; waitForEnd: true }
    stderr: StdioCollector { id: errors; waitForEnd: true }
    onExited: function(exitCode) {
      root.loading = false
      try {
        var result = JSON.parse(output.text)
        if (!result.ok || exitCode !== 0) throw new Error(result.error || "Could not open the control window.")
        if (action === "list") {
          root.machines = result.machines
          if (root.selected) {
            var updated = result.machines.filter(function(m) { return m.machine === root.selected.machine })
            root.selected = updated.length ? updated[0] : null
          }
          root.message = strings.t("ready")
        } else if (action === "connect") {
          root.sessionMachine = result.machine
          root.sessionState = result.state
          root.message = result.message
          root.launched()
        } else if (action === "disconnect" || action === "status") {
          root.sessionState = result.state
          if (result.state === "closed") root.message = strings.t("closed")
        }
      } catch (error) {
        root.failed = true
        root.message = error.message || "Could not read the connection result."
      }
    }
  }
  Timer {
    interval: 5000
    repeat: true
    running: root.visible && root.sessionMachine !== "" && root.sessionState !== "closed"
    onTriggered: if (!root.busy) root.invoke("status", root.sessionMachine)
  }

  ColumnLayout {
    anchors.fill: parent
    spacing: Commons.Style.space(12)
    RowLayout {
      Layout.fillWidth: true
      ColumnLayout {
        Layout.fillWidth: true
        spacing: Commons.Style.space(3)
        PlainText { text: strings.t("title"); font.pixelSize: Commons.Style.space(25); font.bold: true }
        PlainText { text: strings.t("subtitle"); opacity: 0.72 }
      }
      Ui.Button { text: strings.t("refresh"); focusable: true; enabled: !root.busy; onClicked: root.refresh() }
    }
    Ui.TextField {
      id: search
      objectName: "machineSearch"
      Layout.fillWidth: true
      placeholderText: strings.t("search")
      onTextChanged: machineList.currentIndex = -1
      Keys.onDownPressed: { machineList.forceActiveFocus(); machineList.currentIndex = 0 }
      Keys.onReturnPressed: {
        if (root.filtered.length === 1) root.selected = root.filtered[0]
        root.connectSelected()
      }
    }
    ListView {
      id: machineList
      objectName: "machineList"
      Layout.fillWidth: true
      Layout.fillHeight: true
      clip: true
      spacing: Commons.Style.space(4)
      model: root.filtered
      keyNavigationEnabled: true
      onCurrentIndexChanged: if (currentIndex >= 0 && currentIndex < root.filtered.length) root.selected = root.filtered[currentIndex]
      Keys.onReturnPressed: root.connectSelected()
      Controls.ScrollBar.vertical: Controls.ScrollBar {}
      delegate: Rectangle {
        id: machineRow
        required property var modelData
        required property int index
        width: machineList.width
        height: Commons.Style.space(64)
        radius: Commons.Style.space(7)
        color: root.selected && root.selected.machine === modelData.machine ? Qt.alpha(Commons.Color.accent, 0.17) : hover.hovered ? Qt.alpha(Commons.Color.popups.text, 0.07) : "transparent"
        border.width: root.selected && root.selected.machine === modelData.machine ? 1 : 0
        border.color: Commons.Color.accent
        HoverHandler { id: hover }
        TapHandler { onTapped: { root.selected = machineRow.modelData; machineList.currentIndex = machineRow.index } }
        RowLayout {
          anchors.fill: parent
          anchors.margins: Commons.Style.space(10)
          spacing: Commons.Style.space(10)
          Rectangle {
            width: Commons.Style.space(7); height: width; radius: width / 2
            color: machineRow.modelData.local ? Commons.Color.accent : machineRow.modelData.status === "active" ? "#91b989" : "#8b8d97"
          }
          ColumnLayout {
            Layout.fillWidth: true
            spacing: Commons.Style.space(3)
            PlainText { Layout.fillWidth: true; text: machineRow.modelData.machine; elide: Text.ElideRight; font.bold: true }
            PlainText { Layout.fillWidth: true; text: machineRow.modelData.label; elide: Text.ElideRight; opacity: 0.55; font.pixelSize: Commons.Style.space(11) }
          }
          PlainText {
            text: machineRow.modelData.local ? strings.t("local") : machineRow.modelData.status
            opacity: 0.6; font.pixelSize: Commons.Style.space(11)
          }
        }
      }
      PlainText { anchors.centerIn: parent; visible: !root.loading && root.filtered.length === 0; text: strings.t("empty") }
    }
    Rectangle { Layout.fillWidth: true; height: 1; color: Qt.alpha(Commons.Color.popups.text, 0.14) }
    RowLayout {
      Layout.fillWidth: true
      PlainText { text: strings.t("route"); opacity: 0.7 }
      Controls.ComboBox {
        id: routePicker
        Layout.fillWidth: true
        textRole: "label"
        model: [{label: strings.t("auto"), value:"auto"}, {label:strings.t("gliff"), value:"gliff"}, {label:strings.t("vnc"), value:"vnc"}, {label:strings.t("rdp"), value:"rdp"}]
        onActivated: root.route = model[currentIndex].value
        contentItem: PlainText { text: routePicker.displayText; verticalAlignment: Text.AlignVCenter; leftPadding: Commons.Style.space(8) }
      }
    }
    PlainText {
      objectName: "connectionFeedback"
      Layout.fillWidth: true
      text: root.message
      wrapMode: Text.WordWrap
      color: root.failed ? "#e79a90" : Commons.Color.popups.text
      font.pixelSize: Commons.Style.space(12)
    }
    RowLayout {
      Layout.fillWidth: true
      PlainText { Layout.fillWidth: true; Layout.maximumWidth: Commons.Style.space(310); text: strings.t("fit"); wrapMode: Text.WordWrap; opacity: 0.55; font.pixelSize: Commons.Style.space(11) }
      Ui.Button {
        visible: root.sessionState !== "closed" && root.sessionMachine !== ""
        text: strings.t("disconnect"); focusable: true; enabled: !root.busy
        onClicked: root.invoke("disconnect", root.sessionMachine)
      }
      Ui.Button {
        objectName: "connectButton"
        text: root.busy ? "…" : root.failed ? strings.t("retry") : strings.t("connect")
        foreground: Commons.Color.accent
        bordered: true
        focusable: true
        enabled: !root.busy && !!root.selected && !root.selected.local
        onClicked: root.connectSelected()
      }
    }
    PlainText { Layout.fillWidth: true; text: strings.t("inventoryNote"); wrapMode: Text.WordWrap; font.pixelSize: Commons.Style.space(10); opacity: 0.45 }
  }
}
