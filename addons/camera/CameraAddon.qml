import QtQuick
import ".."

// A camera mirror, to check yourself before a call: the webcam shown live,
// mirrored, in the island (see CameraView). The camera runs only while the
// view is open and stops as soon as it closes; nothing is saved.
Addon {
  id: cameraAddon
  views: [{ name: "camera", width: 420, padding: 10, component: cameraView }]
  tiles: [{ key: "camera", title: "Camera", component: cameraTile }]

  Component {
    id: cameraView
    CameraView { host: cameraAddon.host; active: cameraAddon.host.view === "camera" }
  }
  Component {
    id: cameraTile
    CameraTile { host: cameraAddon.host; center: parent.center }
  }
}
