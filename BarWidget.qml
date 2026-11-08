import QtQuick
import Quickshell
import Quickshell.Io
import qs.Ui

// Last zkagent verdict, in the bar.
//
// The widget consumes the document `zkagent verify --json` already emits
// (`verdict`, `reason_code`, `execution_id`, `format`), which exists precisely so
// a program can branch on it instead of parsing English. Three states, and the
// third matters: a missing file is "no verdict yet", never "failed".
BarWidget {
  id: root
  moduleName: "mcpvot.attest"

  readonly property string statusFile: String(setting("statusFile", "~/.local/state/zkagent/last-verdict.json"))
    .replace(/^~/, Quickshell.env("HOME"))
  readonly property int refreshIntervalSec: setting("refreshIntervalSec", 60)

  property string verdict: "unknown"     // accept | reject | error | unknown
  property string reasonCode: ""
  property string executionId: ""
  property double checkedAt: 0

  readonly property int staleAfterSec: setting("staleAfterSec", 900)

  // A verdict older than staleAfterSec is not evidence. Showing last week's green
  // check as if it were current is the exact failure this widget must not have.
  readonly property bool isStale: checkedAt > 0
    && (Date.now() / 1000 - checkedAt) > Math.max(60, staleAfterSec)

  // The project mark's cyan, not a green tick: the widget shows the logo, and the state is carried
  // by its colour plus a one-character suffix, so a rejection is still readable without colour.
  readonly property color okColor: "#22d3ee"
  readonly property color badColor: "#ff6b6b"
  readonly property color warnColor: "#ffb454"
  readonly property color idleColor: "#9aa0a6"
  readonly property color tint: isStale ? idleColor
    : verdict === "accept" ? okColor
    : verdict === "reject" ? badColor
    : verdict === "error" ? warnColor
    : idleColor

  readonly property string suffix: isStale ? ""
    : verdict === "reject" ? "!"
    : verdict === "error" ? "?"
    : ""

  // The mark itself, never a check: "ZK" in the state colour, with "!" for rejected and "?" for
  // could-not-verify so the state survives a colourblind reading and a greyscale screenshot.
  readonly property string glyph: "ZK" + suffix

  function apply(text) {
    if (!text || text.trim() === "") {
      verdict = "unknown"; reasonCode = ""; executionId = ""; checkedAt = 0
      return
    }
    try {
      var doc = JSON.parse(text)
      verdict = String(doc.verdict || "unknown")
      reasonCode = doc.reason_code ? String(doc.reason_code) : ""
      executionId = doc.execution_id === null || doc.execution_id === undefined ? "" : String(doc.execution_id)
      checkedAt = doc.checked_at === null || doc.checked_at === undefined ? 0 : Number(doc.checked_at)
    } catch (e) {
      // An unparseable verdict file is not an acceptance. Say so, do not guess.
      verdict = "error"
      reasonCode = "unparseable"
      executionId = ""
      checkedAt = 0
    }
  }

  FileView {
    id: verdictFile
    path: root.statusFile
    watchChanges: true
    onFileChanged: reload()
    onTextChanged: root.apply(text())
  }

  Timer {
    interval: Math.max(5, root.refreshIntervalSec) * 1000
    running: true
    repeat: true
    onTriggered: verdictFile.reload()
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.glyph
    foreground: root.tint
    tooltipText: root.isStale
      ? "zkagent: verdict is stale (" + Math.round((Date.now() / 1000 - root.checkedAt) / 60) + " min old) · is attest-watch running?"
      : root.verdict === "accept"
        ? "zkagent: accepted" + (root.executionId ? " · execution " + root.executionId : "")
        : root.verdict === "reject"
          ? "zkagent: rejected (" + root.reasonCode + ")"
          : root.verdict === "error"
            ? "zkagent: could not verify (" + root.reasonCode + ")"
            : "zkagent: no verdict yet · is attest-watch running?"
    horizontalMargin: 7.5
    onPressed: function(button) {
      var cmd = String(root.setting("command", ""))
      if (button === Qt.RightButton || cmd === "") {
        // No command configured: say what the widget knows instead of doing
        // something surprising.
        var msg = root.verdict === "unknown"
          ? "No verdict file yet: " + root.statusFile
          : root.verdict + (root.reasonCode ? " (" + root.reasonCode + ")" : "")
            + (root.executionId ? " · execution " + root.executionId : "")
        Quickshell.execDetached(["notify-send", "zkagent", msg])
        return
      }
      if (root.bar) root.bar.run(cmd)
      verdictFile.reload()
    }
  }
}
