import QtQuick
import QtMultimedia
import Quickshell.Widgets

// The camera mirror: the default webcam, live and flipped like a mirror,
// in a 16:9 frame. The camera is only on while `active` (the view is
// open). Esc or a click closes it.
Item {
  id: view
  required property var host
  property bool active: false
  readonly property var theme: host.theme

  implicitHeight: Math.round(width * 9 / 16)
  onActiveChanged: if (active) Qt.callLater(function() { view.forceActiveFocus() })
  Keys.onEscapePressed: host.view = "rest"

  MediaDevices { id: devices }
  // Made only while the view is open: a Camera merely set inactive keeps
  // the device open, busy for other apps.
  Loader {
    id: session
    active: view.active
    sourceComponent: CaptureSession {
      readonly property string error: cam.error !== Camera.NoError ? cam.errorString : ""
      camera: Camera { id: cam; active: true }
      videoOutput: output
    }
  }
  readonly property string error: session.item ? session.item.error : ""

  ClippingRectangle {
    anchors.fill: parent
    radius: 20
    color: view.theme.withAlpha(view.theme.text, 0.06)
    VideoOutput {
      id: output
      anchors.fill: parent
      fillMode: VideoOutput.PreserveAspectCrop
      transform: Scale { origin.x: output.width / 2; xScale: -1 }
    }
    Text {
      anchors.centerIn: parent
      width: parent.width - 40
      horizontalAlignment: Text.AlignHCenter
      wrapMode: Text.WordWrap
      visible: view.error !== "" || devices.videoInputs.length === 0
      text: devices.videoInputs.length === 0 ? "No camera found" : view.error
      color: view.theme.muted
      font.family: view.theme.textFontFamily
      font.pixelSize: view.theme.px(13)
    }
  }
  MouseArea {
    anchors.fill: parent
    onClicked: view.host.view = "rest"
  }
}
