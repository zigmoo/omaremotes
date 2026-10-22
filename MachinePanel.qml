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
  property var launchKeys: ({})
  property string routeNote: ""
  property string feedbackMachine: ""
  readonly property string selectedMachine: selected && typeof selected.machine === "string" ? selected.machine : ""
  readonly property bool focusedFeedback: feedbackMachine !== "" && feedbackMachine === selectedMachine
  onSelectedMachineChanged: clearFeedback()
  readonly property var filtered: machines.filter(function(m) {
    var query = search.text.toLowerCase().trim()
    return !query || (m.machine + " " + m.label).toLowerCase().indexOf(query) !== -1
  })
  readonly property Item focusTarget: machineList
  signal launched()
  signal dismiss()
  Translations { id: strings }

  function clearFeedback() {
    routeNote = ""
    feedbackMachine = ""
    failed = false
    message = strings.t("ready")
  }
  function formatInspection(inspection) {
    if (!inspection || typeof inspection !== "object" || Array.isArray(inspection)) return ""
    var lines = []
    if (typeof inspection.summary === "string") {
      var summary = inspection.summary.replace(/\s+/g, " ").trim().slice(0, 400)
      if (summary) lines.push(summary)
    }
    if (Array.isArray(inspection.nextSteps)) {
      inspection.nextSteps.slice(0, 3).forEach(function(step) {
        if (typeof step !== "string") return
        var text = step.replace(/\s+/g, " ").trim().slice(0, 240)
        if (text) lines.push("• " + text)
      })
    }
    return lines.join("\n")
  }

  function assignLaunchKeys(entries) {
    var keys = Object.assign({}, launchKeys)
    Object.keys(keys).forEach(function(machine) { if (keys[machine] === "q") delete keys[machine] })
    var used = Object.keys(keys).map(function(machine) { return keys[machine] })
    var alphabet = "1234567890abcdefghijklmnoprstuvwxyz"
    entries.filter(function(m) { return !m.local }).map(function(m) { return m.machine }).sort().forEach(function(machine) {
      if (keys[machine]) return
      for (var i = 0; i < alphabet.length; i++) {
        if (used.indexOf(alphabet[i]) === -1) {
          keys[machine] = alphabet[i]
          used.push(alphabet[i])
          break
        }
      }
    })
    launchKeys = keys
  }
  function fastConnect(key) {
    if (busy) return false
    var matches = filtered.filter(function(m) { return !m.local && root.launchKeys[m.machine] === key })
    if (matches.length !== 1) return false
    selected = matches[0]
    machineList.currentIndex = filtered.indexOf(selected)
    invoke("connect", selected.machine)
    return true
  }

  function refresh(silent) {
    if (busy) return
    silentRefresh = silent === true
    invoke("list", "")
  }
  function invoke(action, machine) {
    if (busy) return
    if (action === "connect" || action === "reconnect") clearFeedback()
    if (!controller.running) {
      controller.running = true
      return
    }
    busy = true
    controller.action = action
    controller.machine = machine || ""
    loading = action === "list"
    var keepFeedback = focusedFeedback && (action === "list" || machine !== selectedMachine || (action === "status" && failed && routeNote !== ""))
    if (!(action === "list" && silentRefresh) && !keepFeedback) failed = false
    if (action === "connect" || action === "reconnect") {
      feedbackMachine = machine
      message = strings.t("starting").arg(machine)
    }
    else if (action === "list" && !silentRefresh && !focusedFeedback) message = strings.t("loading")
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
      var connecting = controller.action === "connect" || controller.action === "reconnect"
      var matchesTarget = controller.machine !== "" && controller.machine === selectedMachine
      try {
        if (matchesTarget) {
          var inspection = formatInspection(result.inspection)
          if (inspection || connecting) {
            routeNote = inspection || (typeof result.fallbackReason === "string" ? result.fallbackReason.slice(0, 600) : "")
            feedbackMachine = controller.machine
          }
        }
        if (!result.ok) throw new Error(result.error || "Could not open the control window.")
        if (controller.action === "list") {
          assignLaunchKeys(result.machines)
          machines = result.machines
          availabilitySource = result.availabilitySource || "unavailable"
          if (selected) {
            var updated = result.machines.filter(function(m) { return m.machine === root.selected.machine })
            selected = updated.length ? updated[0] : null
          }
          if (!silentRefresh && !focusedFeedback) message = strings.t("ready")
        } else if (connecting) {
          sessionMachine = result.machine
          sessionState = result.state
          if (matchesTarget) {
            if (sessionState === "desktop_locked") message = result.reason || strings.t("desktopLocked")
            else if (sessionState === "unlocking") message = strings.t("unlockingDesktop")
            else message = result.message
          }
          if (sessionState === "connected" || sessionState === "viewer_open") launched()
        } else if (controller.action === "disconnect" || controller.action === "status") {
          var previousState = sessionState
          sessionState = result.state
          if (matchesTarget && !(focusedFeedback && failed && routeNote !== "")) {
            if (result.state === "closed") message = strings.t("closed")
            else if (result.state === "failed") {
              failed = true
              message = result.reason || strings.t("connectionFailed")
            } else if (result.state === "connected" || result.state === "viewer_open") {
              message = result.message || strings.t("connected").arg(sessionMachine)
              if (previousState !== result.state) launched()
            } else if (result.state === "authenticated") message = strings.t("waitingForDesktop")
            else if (result.state === "retrying") message = strings.t("retryingLogin")
            else if (result.state === "desktop_locked") message = result.reason || strings.t("desktopLocked")
            else if (result.state === "unlocking") message = strings.t("unlockingDesktop")
          }
        }
      } catch (error) {
        if ((controller.machine === "" || matchesTarget) && !(controller.action === "list" && focusedFeedback)) {
          failed = true
          message = (error.message || "Could not read the connection result.").slice(0, 320)
        }
      }
      busy = false
  }

  Process {
    id: controller
    property string action: ""
    property string machine: ""
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
        PlainText { text: strings.t("subtitle") }
      }
      Ui.Button { text: strings.t("refresh"); focusable: true; enabled: !root.busy; onClicked: root.refresh() }
    }
    Ui.TextField {
      id: search
      objectName: "machineSearch"
      Layout.fillWidth: true
      placeholderText: strings.t("search")
      placeholderTextColor: Commons.Color.popups.text
      onTextChanged: machineList.currentIndex = -1
      Keys.onDownPressed: { machineList.forceActiveFocus(); machineList.currentIndex = 0 }
      Keys.onReturnPressed: {
        if (root.filtered.length === 1) {
          root.selected = root.filtered[0]
          root.connectSelected()
        } else machineList.forceActiveFocus()
      }
    }
    PlainText {
      Layout.fillWidth: true
      text: search.activeFocus ? strings.t("searchKeys") : strings.t("launchKeys")
      wrapMode: Text.WordWrap
      font.pixelSize: Commons.Style.space(11)
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
      Keys.onPressed: function(event) {
        if (!activeFocus || event.isAutoRepeat || event.modifiers !== Qt.NoModifier) return
        if (event.key === Qt.Key_Q) {
          root.dismiss()
          event.accepted = true
        } else if (event.key === Qt.Key_Slash) {
          search.forceActiveFocus()
          event.accepted = true
        } else if (root.fastConnect(event.text.toLowerCase())) event.accepted = true
      }
      Controls.ScrollBar.vertical: Controls.ScrollBar {}
      delegate: Rectangle {
        id: machineRow
        required property var modelData
        required property int index
        readonly property bool isSelected: !!root.selected && root.selected.machine === modelData.machine
        width: machineList.width
        height: Commons.Style.space(64)
        radius: Commons.Style.space(7)
        color: isSelected ? Qt.alpha(Commons.Color.accent, 0.17) : hover.hovered ? Qt.alpha(Commons.Color.popups.text, 0.07) : "transparent"
        border.width: isSelected ? 1 : 0
        border.color: Commons.Color.accent
        HoverHandler { id: hover }
        RowLayout {
          anchors.fill: parent
          anchors.margins: Commons.Style.space(10)
          spacing: Commons.Style.space(10)
          Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            TapHandler { onTapped: { root.selected = machineRow.modelData; machineList.currentIndex = machineRow.index; machineList.forceActiveFocus() } }
            RowLayout {
              anchors.fill: parent
              spacing: Commons.Style.space(10)
              Rectangle {
                visible: !machineRow.modelData.local && !!root.launchKeys[machineRow.modelData.machine]
                Layout.preferredWidth: Commons.Style.space(23)
                Layout.preferredHeight: Commons.Style.space(25)
                radius: Commons.Style.space(4)
                color: Qt.alpha(Commons.Color.popups.text, 0.06)
                border.color: Qt.alpha(Commons.Color.popups.text, 0.25)
                PlainText { anchors.centerIn: parent; text: root.launchKeys[machineRow.modelData.machine] || ""; font.bold: true }
              }
              Rectangle {
                width: Commons.Style.space(7); height: width; radius: width / 2
                color: machineRow.modelData.local ? Commons.Color.accent : machineRow.modelData.availability === "online" ? "#91b989" : machineRow.modelData.availability === "offline" ? "#c98780" : "#8b8d97"
              }
              ColumnLayout {
                Layout.fillWidth: true
                spacing: Commons.Style.space(3)
                PlainText { Layout.fillWidth: true; text: machineRow.modelData.machine; elide: Text.ElideRight; font.bold: true }
                PlainText { Layout.fillWidth: true; text: machineRow.modelData.label + (machineRow.modelData.platform ? " · " + machineRow.modelData.platform : ""); elide: Text.ElideRight; font.pixelSize: Commons.Style.space(11) }
              }
              PlainText {
                text: machineRow.modelData.local ? strings.t("local") : strings.t("ts." + machineRow.modelData.availability)
                font.pixelSize: Commons.Style.space(11)
              }
            }
          }
          Item {
            Layout.preferredWidth: rowConnect.implicitWidth
            Layout.fillHeight: true
            Ui.Button {
              id: rowConnect
              objectName: "connect-" + machineRow.modelData.machine
              anchors.centerIn: parent
              visible: hover.hovered || machineRow.isSelected || activeFocus
              text: strings.t("connect")
              tooltipText: strings.t("connectMachine").arg(machineRow.modelData.machine)
              Accessible.name: tooltipText
              foreground: Commons.Color.accent
              bordered: true
              focusable: true
              enabled: !root.busy && !machineRow.modelData.local
              onClicked: {
                root.selected = machineRow.modelData
                machineList.currentIndex = machineRow.index
                root.invoke("connect", machineRow.modelData.machine)
              }
            }
          }
        }
      }
      PlainText { anchors.centerIn: parent; visible: !root.loading && root.filtered.length === 0; text: strings.t("empty") }
    }
    Rectangle { Layout.fillWidth: true; height: 1; color: Qt.alpha(Commons.Color.popups.text, 0.14) }
    RowLayout {
      Layout.fillWidth: true
      PlainText { text: strings.t("route") }
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
    PlainText {
      objectName: "routeFeedback"
      Layout.fillWidth: true
      visible: root.routeNote !== ""
      text: root.routeNote
      wrapMode: Text.WordWrap
      font.pixelSize: Commons.Style.space(11)
    }
    RowLayout {
      Layout.fillWidth: true
      PlainText { Layout.fillWidth: true; Layout.maximumWidth: Commons.Style.space(310); text: strings.t("fit"); wrapMode: Text.WordWrap; font.pixelSize: Commons.Style.space(11) }
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
    PlainText { Layout.fillWidth: true; text: strings.t(root.availabilitySource === "tailscale" ? "tailscaleNote" : "tailscaleMissing"); wrapMode: Text.WordWrap; font.pixelSize: Commons.Style.space(10) }
  }
}
