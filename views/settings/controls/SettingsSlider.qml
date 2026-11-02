import QtQuick

// A plain slider for a setting: a track and a knob, dragged or clicked.
// With `editable`, a small field beside it shows the value and takes a typed
// one (Enter or leaving the field sets it, kept between `from` and `to`).
// `view` is the SettingsView, for its colours; `onMoved` gets the value.
Item {
  id: slider
  required property var view
  property real from: 0
  property real to: 1
  property real value: 0
  property real step: 0.05
  property bool editable: false
  // Shown after the number in the field, as "px".
  property string unit: ""
  signal moved(real value)
  implicitWidth: view.controlWidth
  implicitHeight: editable ? 28 : 22
  readonly property real fraction: Math.max(0, Math.min(1, (value - from) / (to - from)))

  Item {
    id: track
    anchors.left: parent.left
    anchors.right: slider.editable ? valueField.left : parent.right
    anchors.rightMargin: slider.editable ? 12 : 0
    height: parent.height
    Rectangle {
      anchors.verticalCenter: parent.verticalCenter
      width: parent.width; height: 4; radius: 2
      color: slider.view.host.theme.solid("stronger")
      Rectangle { width: parent.width * slider.fraction; height: parent.height; radius: 2; color: slider.view.accent }
    }
    Rectangle {
      x: (track.width - width) * slider.fraction
      anchors.verticalCenter: parent.verticalCenter
      width: 18; height: 18; radius: 9; color: "#ffffff"
    }
    MouseArea {
      anchors.fill: parent
      function setFrom(x) {
        var f = Math.max(0, Math.min(1, (x - 9) / (track.width - 18)))
        slider.moved(Math.round((slider.from + f * (slider.to - slider.from)) / slider.step) * slider.step)
      }
      onPressed: function(m) { setFrom(m.x) }
      onPositionChanged: function(m) { if (pressed) setFrom(m.x) }
    }
  }

  SettingsTextField {
    id: valueField
    visible: slider.editable
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    width: visible ? 64 : 0
    view: slider.view
    value: slider.format(slider.value)
    onCommitted: function(text) {
      var n = parseFloat(text)
      if (!isNaN(n)) {
        n = Math.round(n / slider.step) * slider.step
        slider.moved(Math.max(slider.from, Math.min(slider.to, n)))
      }
      // Back to the value as set, with its unit, whatever was typed.
      Qt.callLater(valueField.reset)
    }
  }
  function format(v) {
    var digits = slider.step < 1 ? Math.min(3, Math.ceil(-Math.log(slider.step) / Math.LN10)) : 0
    return Number(v).toFixed(digits) + (slider.unit ? " " + slider.unit : "")
  }
}
