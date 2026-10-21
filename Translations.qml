import QtQuick
import Quickshell.Io

// The Zbook shell predates Commons.Translations. Keep the happy-path catalog
// file-backed; integrate the native live-language service before release.
Item {
  id: root
  property var catalog: ({})
  function t(key) { return catalog[key] || key }
  FileView {
    id: file
    path: decodeURIComponent(Qt.resolvedUrl("i18n/en.json").toString().replace(/^file:\/\//, ""))
    watchChanges: true
    onFileChanged: reload()
    onLoaded: {
      try { root.catalog = JSON.parse(text()) }
      catch (error) { root.catalog = ({}) }
    }
  }
}
