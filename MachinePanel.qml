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
  property bool silentRefresh: false
  property string availabilitySource: "unavailable"
  property string sessionMachine: ""
  property string sessionState: "closed"
  property bool busy: false
  readonly property var filtered: machines.filter(function(m) {
    var query = search.text.toLowerCase().trim()
    return !query || (m.machine + " " + m.label).toLowerCase().indexOf(query) !== -1
  })
  readonly property Item focusTarget: search
  signal launched()
  Translations { id: strings }

  function refresh(silent) {
    if (busy) return
    silentRefresh = silent === true
    invoke("list", "")
  }
  function invoke(action, machine) {
    if (busy) return
    if (!controller.running) {
      controller.running = true
      return
    }
    busy = true
    controller.action = action
    loading = action === "list"
    if (!(action === "list" && silentRefresh)) failed = false
    if (action === "connect" || action === "reconnect") message = strings.t("starting").arg(machine)
    else if (action === "list" && !silentRefresh) message = strings.t("loading")
    var request = {action:action, route:route}
    if (machine) request.machine = machine
    controller.write(JSON.stringify(request) + "\n")
  }
  function connectSelected() {
    if (selected && !selected.local) invoke("connect", selected.machine)
  }
  Component.onDestruction: if (controller.running) controller.write('{"action":"quit"}\n')

  function acceptResult(result) {
      loading = false
      try {
        if (!result.ok) throw new Error(result.error || "Could not open the control window.")
        if (controller.action === "list") {
          machines = result.machines
          availabilitySource = result.availabilitySource || "unavailable"
          if (selected) {
            var updated = result.machines.filter(function(m) { return m.machine === root.selected.machine })
            selected = updated.length ? updated[0] : null
          }
          if (!silentRefresh) message = strings.t("ready")
        } else if (controller.action === "connect" || controller.action === "reconnect") {
          sessionMachine = result.machine
          sessionState = result.state
          message = result.message
          if (sessionState === "connected" || sessionState === "viewer_open") launched()
        } else if (controller.action === "disconnect" || controller.action === "status") {
          var previousState = sessionState
          sessionState = result.state
          if (result.state === "closed") message = strings.t("closed")
          else if (result.state === "failed") {
            failed = true
            message = result.reason || strings.t("connectionFailed")
          } else if (result.state === "connected") {
            message = strings.t("connected").arg(sessionMachine)
            if (previousState !== "connected") launched()
          } else if (result.state === "authenticated") message = strings.t("waitingForDesktop")
          else if (result.state === "retrying") message = strings.t("retryingLogin")
        }
      } catch (error) {
        failed = true
        message = error.message || "Could not read the connection result."
      }
      busy = false
  }

  Process {
    id: controller
    property string action: ""
    property string lastError: ""
    command: ["bash", "-lc", "exec oma_remotes_tool serve"]
    running: true
    stdinEnabled: true
    onStarted: root.refresh()
    stdout: SplitParser {
      onRead: function(data) {
        try { root.acceptResult(JSON.parse(data)) }
        catch (error) { root.acceptResult({ok:false,error:"Could not read the connection result."}) }
      }
    }
    stderr: SplitParser { onRead: function(data) { controller.lastError = data.slice(0, 400) } }
    onExited: function(exitCode) {
      root.busy = false
      if (exitCode !== 0) root.acceptResult({ok:false,error:"The connection helper stopped. Press Refresh to restart it."})
    }
  }
  Timer {
    interval: 15000
    repeat: true
    running: root.visible
    onTriggered: if (!root.busy) root.refresh(true)
  }
  Timer {
    interval: 5000
    repeat: true
    running: root.visible && root.sessionMachine !== "" && root.sessionState !== "closed" && root.sessionState !== "failed"
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
            color: machineRow.modelData.local ? Commons.Color.accent : machineRow.modelData.availability === "online" ? "#91b989" : machineRow.modelData.availability === "offline" ? "#c98780" : "#8b8d97"
          }
          ColumnLayout {
            Layout.fillWidth: true
            spacing: Commons.Style.space(3)
            PlainText { Layout.fillWidth: true; text: machineRow.modelData.machine; elide: Text.ElideRight; font.bold: true }
            PlainText { Layout.fillWidth: true; text: machineRow.modelData.label + (machineRow.modelData.platform ? " · " + machineRow.modelData.platform : ""); elide: Text.ElideRight; opacity: 0.55; font.pixelSize: Commons.Style.space(11) }
          }
          PlainText {
            text: machineRow.modelData.local ? strings.t("local") : strings.t("ts." + machineRow.modelData.availability)
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
        visible: root.sessionState !== "closed" && root.selected && root.selected.machine === root.sessionMachine
        text: strings.t("reconnect"); focusable: true; enabled: !root.busy
        onClicked: root.invoke("reconnect", root.sessionMachine)
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
    PlainText { Layout.fillWidth: true; text: strings.t(root.availabilitySource === "tailscale" ? "tailscaleNote" : "tailscaleMissing"); wrapMode: Text.WordWrap; font.pixelSize: Commons.Style.space(10); opacity: 0.45 }
  }
}
