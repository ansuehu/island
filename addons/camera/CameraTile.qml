import QtQuick
import "../../views/control-center"

// The control center tile: opens the camera mirror.
CcTile {
  required property var host

  anchors.fill: parent
  icon: "󰄀"
  title: "Camera"
  subtitle: "Mirror"
  checked: host.view === "camera"
  onClicked: host.view = "camera"
}
