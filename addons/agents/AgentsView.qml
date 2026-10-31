import QtQuick

// The agents live activity, expanded: each session at work (up to four,
// newest first) with its project, the prompt it's answering, and what it's
// doing now, timed. Opened by clicking the pill; Esc or a click outside
// closes it.
Item {
  id: view
  required property var agents
  property bool active: false
  readonly property var host: agents.host
  readonly property var theme: host.theme
  implicitWidth: 400
  implicitHeight: list.implicitHeight

  onActiveChanged: if (active) Qt.callLater(function() { view.forceActiveFocus() })
  Keys.onEscapePressed: host.view = "rest"

  function stateText(s) {
    if (s.state === "asking") return "Waiting for you"
    if (s.state === "done") return "Done"
    if (s.tool) return "Running " + s.tool
    return "Thinking"
  }
  function stateColor(s) {
    return s.state === "asking" ? theme.system.orange : s.state === "done" ? theme.system.green : agents.ink
  }
  function elapsed(s) {
    if (!s.startedAt) return ""
    return agents.timeText((s.state === "done" ? s.doneAt : agents.now) - s.startedAt)
  }

  // The turn timers tick only while the pill shows; the view needs them too.
  Timer {
    interval: 1000
    repeat: true
    running: view.active
    onTriggered: view.agents.now = Date.now()
  }

  Column {
    id: list
    width: parent.width
    spacing: 8
    Text {
      text: view.agents.sessions.length ? "Claude Code" : "No agent at work"
      color: view.theme.text
      font.family: view.theme.textFontFamily
      font.pixelSize: view.theme.px(15)
      font.weight: Font.DemiBold
    }
    Repeater {
      model: view.agents.sessions
      delegate: Rectangle {
        required property var modelData
        width: list.width
        height: body.implicitHeight + 20
        radius: 14
        color: view.theme.fill("subtle")
        Column {
          id: body
          x: 14
          y: 10
          width: parent.width - 28
          spacing: 3
          Row {
            spacing: 8
            width: parent.width
            Rectangle {
              width: 8; height: 8; radius: 4
              y: (project.height - height) / 2
              color: view.stateColor(modelData)
            }
            Text {
              id: project
              width: parent.width - 16 - time.width - 8
              text: modelData.cwd ? modelData.cwd.replace(/\/+$/, "").split("/").pop() : "Session"
              elide: Text.ElideRight
              color: view.theme.text
              font.family: view.theme.textFontFamily
              font.pixelSize: view.theme.px(13)
              font.weight: Font.DemiBold
            }
            Text {
              id: time
              text: view.elapsed(modelData)
              color: view.theme.muted
              font.family: view.theme.textFontFamily
              font.pixelSize: view.theme.px(12)
              font.features: { "tnum": 1 }
            }
          }
          Text {
            width: parent.width
            visible: text !== ""
            text: modelData.prompt || ""
            elide: Text.ElideRight
            maximumLineCount: 2
            wrapMode: Text.Wrap
            color: view.theme.muted
            font.family: view.theme.textFontFamily
            font.pixelSize: view.theme.px(12)
          }
          Text {
            text: view.stateText(modelData)
            color: view.stateColor(modelData)
            font.family: view.theme.textFontFamily
            font.pixelSize: view.theme.px(12)
            font.weight: Font.Medium
          }
        }
      }
    }
  }
}
