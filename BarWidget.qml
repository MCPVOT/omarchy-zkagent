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

  // A cheap clock, so "is this verdict still current" keeps moving without touching the file.
  // Before this, staleness only recomputed when the verdict file was re-read, which tied one
  // concern (how old is the evidence) to another (has the evidence changed).
  property double nowSec: Date.now() / 1000

  // A verdict older than staleAfterSec is not evidence. Showing last week's green
  // check as if it were current is the exact failure this widget must not have.
  readonly property bool isStale: checkedAt > 0
    && (nowSec - checkedAt) > Math.max(60, staleAfterSec)

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

  // Letters, not a pictogram. A shield-with-padlock glyph was tried here and at bar size it
  // collapsed into a bird-shaped smudge; "ZK" is unambiguous next to the other bar icons and matches
  // the app icon exactly. "!" and "?" keep the state readable in greyscale.
  readonly property string glyph: "ZK" + suffix

  function apply(text) {
    if (!text || text.trim() === "") {
      set("unknown", "", "", 0)
      return
    }
    try {
      var doc = JSON.parse(text)
      set(String(doc.verdict || "unknown"),
        doc.reason_code ? String(doc.reason_code) : "",
        doc.execution_id === null || doc.execution_id === undefined ? "" : String(doc.execution_id),
        doc.checked_at === null || doc.checked_at === undefined ? 0 : Number(doc.checked_at))
    } catch (e) {
      // An unparseable verdict file is not an acceptance. Say so, do not guess.
      set("error", "unparseable", "", 0)
    }
  }

  // Write only what changed. `reload()` fires on every watch event and on the fallback tick, and a
  // blanket write forced the bar to re-evaluate every binding and repaint the button even when the
  // document was byte-identical. A bar widget that repaints hourly for nothing is a cost the whole
  // shell pays, twenty times over.
  function set(v, reason, execId, at) {
    if (verdict !== v) verdict = v
    if (reasonCode !== reason) reasonCode = reason
    if (executionId !== execId) executionId = execId
    if (checkedAt !== at) checkedAt = at
  }

  FileView {
    id: verdictFile
    path: root.statusFile
    watchChanges: true
    onFileChanged: reload()
    onTextChanged: root.apply(text())
  }

  // The file is watched, so this is only a fallback: a writer that replaces the file by rename leaves
  // inotify holding the old inode, and a day when the watch is unavailable should still show truth.
  Timer {
    interval: Math.max(5, root.refreshIntervalSec) * 1000
    running: true
    repeat: true
    onTriggered: verdictFile.reload()
  }

  // Staleness alone: no file IO, no repaint unless the answer actually changes.
  Timer {
    interval: 30000
    running: true
    repeat: true
    onTriggered: root.nowSec = Date.now() / 1000
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
