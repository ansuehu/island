import QtQuick
import QtMultimedia
import Quickshell.Widgets
import "../../components"

// The camera mirror: the default webcam, live and flipped like a mirror,
// in a 16:9 frame. The camera is only on while `active` (the view is
// open). The shutter saves a photo to ~/Pictures; Esc or a click
// elsewhere closes it.
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
      imageCapture: ImageCapture {
        onImageSaved: function(id, path) { view.saved = String(path).split("/").pop(); savedTimer.restart() }
        onErrorOccurred: function(id, error, message) { view.saved = "Couldn't save: " + message; savedTimer.restart() }
      }
    }
  }
  readonly property string error: session.item ? session.item.error : ""

  // A photo, as the camera sees it (not mirrored), into ~/Pictures.
  property string saved: ""
  Timer { id: savedTimer; interval: 2500; onTriggered: view.saved = "" }
  function pad(n) { return (n < 10 ? "0" : "") + n }
  function takePhoto() {
    var capture = session.item ? session.item.imageCapture : null
    if (!capture || !capture.readyForCapture) return
    var d = new Date()
    var name = "photo-" + d.getFullYear() + "-" + pad(d.getMonth() + 1) + "-" + pad(d.getDate())
      + "_" + pad(d.getHours()) + "-" + pad(d.getMinutes()) + "-" + pad(d.getSeconds()) + ".jpg"
    capture.captureToFile(view.host.home + "/Pictures/" + name)
    flash.opacity = 0.85
    flashOut.restart()
  }

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

  // The shutter's white blink.
  Rectangle {
    id: flash
    anchors.fill: parent
    radius: 20
    color: "#ffffff"
    opacity: 0
    NumberAnimation { id: flashOut; target: flash; property: "opacity"; to: 0; duration: 350; easing.type: Easing.OutQuad }
  }
  // The shutter: above the click-to-close area.
  Rectangle {
    // On the right edge, off the face in the middle.
    anchors.right: parent.right
    anchors.rightMargin: 14
    anchors.verticalCenter: parent.verticalCenter
    visible: view.error === "" && devices.videoInputs.length > 0
    width: 52; height: 52; radius: 26
    color: "transparent"
    border.width: 3
    border.color: "#ffffff"
    scale: shutterMouse.pressed ? 0.9 : 1
    Behavior on scale { MotionAnimation { theme: view.theme; pace: shutterMouse.pressed ? "press" : "standard" } }
    Rectangle {
      anchors.centerIn: parent
      width: 40; height: 40; radius: 20
      color: shutterMouse.containsMouse ? "#ffffff" : Qt.rgba(1, 1, 1, 0.85)
    }
    MouseArea {
      id: shutterMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: view.takePhoto()
    }
  }
  Rectangle {
    visible: view.saved !== ""
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.top: parent.top
    anchors.topMargin: 12
    width: savedText.implicitWidth + 20
    height: 26
    radius: 13
    color: Qt.rgba(0, 0, 0, 0.6)
    Text {
      id: savedText
      anchors.centerIn: parent
      text: view.saved.indexOf("Couldn't") === 0 ? view.saved : "Saved to Pictures"
      color: "#ffffff"
      font.family: view.theme.textFontFamily
      font.pixelSize: view.theme.px(12)
    }
  }
}
