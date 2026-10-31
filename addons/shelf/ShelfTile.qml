import QtQuick
import "../../views/control-center"

// The control center tile: how many things are parked, lit while any are.
// Opens the shelf view. `shelf` is the ShelfAddon.
CcTile {
  required property var shelf
  readonly property int count: shelf.items.length

  anchors.fill: parent
  icon: "󰆼"
  title: "Shelf"
  subtitle: count === 0 ? "Empty" : count === 1 ? "1 item" : count + " items"
  checked: count > 0
  onClicked: shelf.host.view = "shelf"
}
