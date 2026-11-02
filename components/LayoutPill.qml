import QtQuick

// Shown for a moment when Super + L changes the workspace's layout: the
// layout's glyph leading, its name in the middle, and trailing a chip per
// layout with a capsule that slides from the one you left, like KeyboardPill.
IslandPill {
  id: pill
  readonly property var mode: host.layoutModes[host.workspaceModeIndex]
  readonly property int chip: 30
  readonly property int gap: 6
  shown: host.layoutPill
  pillWidth: 150 + host.layoutModes.length * (chip + gap)

  PillReveal { id: reveal; theme: pill.host.theme; shown: pill.shown }

  Text {
    id: leading
    anchors.left: parent.left
    anchors.leftMargin: 14
    anchors.verticalCenter: parent.verticalCenter
    text: pill.mode.glyph
    color: pill.host.theme.accent
    font.family: pill.host.theme.fontFamily
    font.pixelSize: pill.host.theme.px(18)
    opacity: reveal.leadingIn
    PillPart { progress: reveal.leadingIn }
  }

  Text {
    opacity: reveal.middleIn
    PillPart { progress: reveal.middleIn; scaleFrom: 0.94 }
    anchors.left: leading.right
    anchors.leftMargin: 10
    anchors.right: trailing.left
    anchors.rightMargin: 12
    anchors.verticalCenter: parent.verticalCenter
    text: pill.mode.name
    elide: Text.ElideRight
    color: "#ffffff"
    font.family: pill.host.theme.textFontFamily
    font.pixelSize: pill.host.theme.px(13)
    font.weight: Font.Medium
    font.letterSpacing: -0.2
  }

  Item {
    id: trailing
    opacity: reveal.trailingIn
    PillPart { progress: reveal.trailingIn }
    anchors.right: parent.right
    anchors.rightMargin: 12
    anchors.verticalCenter: parent.verticalCenter
    width: pill.host.layoutModes.length * (pill.chip + pill.gap) - pill.gap
    height: 22

    Rectangle {
      x: pill.host.workspaceModeIndex * (pill.chip + pill.gap)
      width: pill.chip
      height: parent.height
      radius: height / 2
      color: pill.host.settings.colorfulLiveActivities ? "#ffffff" : pill.host.theme.accent
      Behavior on x { MotionAnimation { theme: pill.host.theme; pace: "expressive" } }
    }

    Row {
      spacing: pill.gap
      Repeater {
        model: pill.host.layoutModes
        delegate: Text {
          required property var modelData
          required property int index
          width: pill.chip
          height: trailing.height
          horizontalAlignment: Text.AlignHCenter
          verticalAlignment: Text.AlignVCenter
          text: modelData.glyph
          color: index !== pill.host.workspaceModeIndex ? Qt.rgba(1, 1, 1, 0.45)
            : pill.host.settings.colorfulLiveActivities ? "#000000" : pill.host.theme.accentText
          Behavior on color { MotionColorAnimation { theme: pill.host.theme } }
          font.family: pill.host.theme.fontFamily
          font.pixelSize: pill.host.theme.px(12)
        }
      }
    }
  }
}
