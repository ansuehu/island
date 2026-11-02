import QtQuick
import Quickshell.Widgets
import "../../components"

// The shelf view: what's parked, as cards in a row (an image's thumbnail,
// or a glyph for other files, links, and text), four a row, newest last. With two or
// more, a stack leads the row: drag it to drop everything at once. Click
// cards to select them and drag any selected one to drop the selection, or
// drag an unselected card to drop just that one. Double-click opens it
// (text is copied); its × removes it. Esc clears the selection, then
// closes. `shelf` is the ShelfAddon.
Item {
  id: view
  required property var shelf
  property bool active: false
  readonly property var host: shelf.host
  readonly property var theme: host.theme

  readonly property int columns: 4
  readonly property real gap: 10
  readonly property real cardWidth: Math.floor((width - (columns - 1) * gap) / columns)
  readonly property int rows: Math.ceil((shelf.items.length + (shelf.items.length > 1 ? 1 : 0)) / columns)
  implicitHeight: header.height + 10 + (shelf.items.length ? grid.height : 64)
  onActiveChanged: {
    // A drag that folded the shelf away may not have reported its end.
    host.draggingOut = false
    if (active) Qt.callLater(function() { if (view) view.forceActiveFocus() })
  }
  // Esc drops the selection first, then closes.
  Keys.onEscapePressed: if (selected.length) selected = []; else host.view = "rest"

  // The selected items' values; dragging any of them drags them all.
  property var selected: []
  readonly property var selectedItems: shelf.items.filter(function(it) { return view.selected.indexOf(it.value) !== -1 })
  function toggle(item) {
    var i = selected.indexOf(item.value)
    selected = i === -1 ? selected.concat([item.value]) : selected.filter(function(v) { return v !== item.value })
  }

  function isImage(item) { return item.kind === "file" && /\.(png|jpe?g|gif|webp|bmp|svg|avif)$/i.test(item.value) }
  function glyph(item) {
    return item.kind === "text" ? "󰦨" : item.kind === "link" ? "󰌹"
      : /\/$|^[^.]+$/.test(item.name) ? "󰉋" : "󰈔"
  }

  // An item's picture: its thumbnail, or its glyph on a tile.
  component Thumb: ClippingRectangle {
    id: thumbRoot
    required property var item
    radius: 10
    color: view.isImage(item) ? "transparent" : view.theme.fill("raised")
    Image {
      anchors.fill: parent
      visible: view.isImage(thumbRoot.item)
      source: visible ? thumbRoot.item.value : ""
      sourceSize.width: 112
      sourceSize.height: 112
      fillMode: Image.PreserveAspectCrop
      asynchronous: true
    }
    Text {
      anchors.centerIn: parent
      visible: !view.isImage(thumbRoot.item)
      text: view.glyph(thumbRoot.item)
      color: view.theme.accent
      font.family: view.theme.fontFamily
      font.pixelSize: Math.round(thumbRoot.height * 0.6)
    }
  }

  // A card that drags `items` out of the island as one drop, as Qt's
  // external drag-and-drop example does: a DragHandler that moves nothing
  // and starts the system drag, with a picture of the card under the
  // pointer. Once it's going the shelf folds away, out of the drop's path.
  component Card: Item {
    id: card
    property var items: []
    readonly property bool pressed: tap.pressed
    readonly property bool hovered: hover.hovered
    signal clicked()
    signal doubleClicked()
    width: view.cardWidth
    height: 108

    Drag.dragType: Drag.Automatic
    Drag.supportedActions: Qt.CopyAction
    Drag.mimeData: view.shelf.mimeFor(card.items)
    Drag.hotSpot.x: width / 2
    Drag.hotSpot.y: height / 2
    Drag.onDragStarted: foldAway.start()
    Drag.onDragFinished: view.host.draggingOut = false
    // A beat after the drag starts, so the compositor has taken it first.
    Timer { id: foldAway; interval: 150; onTriggered: view.host.view = "rest" }

    HoverHandler {
      id: hover
      cursorShape: Qt.PointingHandCursor
      // The drag's picture, taken while the pointer is on the card.
      onHoveredChanged: if (hovered) card.grabToImage(function(result) { card.Drag.imageSource = result.url })
    }
    TapHandler {
      id: tap
      // Shrink the island's input region to the island on press, so the
      // drop goes to the window below, not the click-outside area.
      onPressedChanged: if (pressed) view.host.draggingOut = true
      onTapped: { view.host.draggingOut = false; tapCount === 2 ? card.doubleClicked() : card.clicked() }
      onCanceled: if (!card.Drag.active) view.host.draggingOut = false
    }
    DragHandler {
      id: dragger
      target: null
      // Not the grid's scroll: it has the pointer once it moves.
      grabPermissions: PointerHandler.CanTakeOverFromAnything
      // Started once, not bound: the shelf folding away ends the handler,
      // and that mustn't end the drag with it.
      onActiveChanged: if (active) { view.host.draggingOut = true; card.Drag.active = true }
    }
  }

  Item {
    id: header
    width: parent.width
    height: 22
    Text {
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      text: view.selectedItems.length ? "Shelf · " + view.selectedItems.length + " selected" : "Shelf"
      color: view.theme.text
      font.family: view.theme.textFontFamily
      font.pixelSize: view.theme.px(15)
      font.weight: Font.DemiBold
    }
    Text {
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      visible: view.shelf.items.length > 0
      text: "Clear"
      color: clearMouse.containsMouse ? view.theme.text : view.theme.muted
      font.family: view.theme.textFontFamily
      font.pixelSize: view.theme.px(13)
      MouseArea {
        id: clearMouse
        anchors.fill: parent
        anchors.margins: -6
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: view.shelf.clear()
      }
    }
  }

  Text {
    visible: view.shelf.items.length === 0
    anchors.top: header.bottom
    anchors.bottom: parent.bottom
    width: parent.width
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
    text: "Drag files, text, or links onto the island"
    color: view.theme.muted
    font.family: view.theme.textFontFamily
    font.pixelSize: view.theme.px(13)
  }

  // Four cards a row, the stack first; past three rows it scrolls.
  Flickable {
    id: grid
    anchors.top: header.bottom
    anchors.topMargin: 10
    width: parent.width
    height: Math.min(view.rows, 3) * (108 + view.gap) - view.gap
    visible: view.shelf.items.length > 0
    clip: true
    contentHeight: flow.height
    boundsBehavior: Flickable.StopAtBounds
    // Newest at the end, so show the end when something is added.
    onContentHeightChanged: contentY = Math.max(0, contentHeight - height)

    Flow {
      id: flow
      width: grid.width
      spacing: view.gap

      // The stack: the last three items fanned out, and how many there are.
      Card {
        id: stack
        visible: view.shelf.items.length > 1
        items: view.shelf.items
        Rectangle {
          anchors.fill: parent
          radius: 14
          color: stack.hovered ? view.theme.withAlpha(view.theme.accent, 0.28) : view.theme.withAlpha(view.theme.accent, 0.16)
          border.width: 1
          border.color: view.theme.withAlpha(view.theme.accent, 0.5)
          scale: stack.pressed ? 0.96 : 1
          Behavior on scale { MotionAnimation { theme: view.theme; pace: stack.pressed ? "press" : "standard" } }
          Repeater {
            model: view.shelf.items.slice(-3)
            Thumb {
              required property var modelData
              required property int index
              readonly property int fromTop: Math.min(3, view.shelf.items.length) - 1 - index
              item: modelData
              width: 48
              height: 48
              x: (parent.width - width) / 2 + (fromTop === 0 ? 0 : fromTop === 1 ? -9 : 9)
              y: 14 + fromTop * 2
              rotation: fromTop === 0 ? 0 : fromTop === 1 ? -10 : 10
              z: -fromTop
              // Opaque, so the fanned cards don't show through each other.
              color: view.isImage(modelData) ? "transparent" : Qt.tint(view.theme.background, view.theme.fill("raised"))
              border.width: 1
              border.color: view.theme.background
            }
          }
          Text {
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 12
            anchors.horizontalCenter: parent.horizontalCenter
            text: "All " + view.shelf.items.length
            color: view.theme.text
            font.family: view.theme.textFontFamily
            font.pixelSize: view.theme.px(11)
            font.weight: Font.DemiBold
          }
        }
      }

      Repeater {
        model: view.shelf.items
        delegate: Card {
          id: card
          required property var modelData
          required property int index
          readonly property bool isSelected: view.selected.indexOf(modelData.value) !== -1
          items: isSelected ? view.selectedItems : [modelData]
          onClicked: view.toggle(modelData)
          onDoubleClicked: view.shelf.activate(modelData)

          Rectangle {
            anchors.fill: parent
            z: -1
            radius: 14
            color: card.isSelected ? view.theme.withAlpha(view.theme.accent, card.hovered ? 0.28 : 0.2)
              : card.hovered ? view.theme.fill("raised") : view.theme.withAlpha(view.theme.text, 0.06)
            border.width: card.isSelected ? 1 : 0
            border.color: view.theme.withAlpha(view.theme.accent, 0.6)
            scale: card.pressed ? 0.96 : 1
            Behavior on scale { MotionAnimation { theme: view.theme; pace: card.pressed ? "press" : "standard" } }

            Thumb {
              id: thumb
              item: card.modelData
              anchors.horizontalCenter: parent.horizontalCenter
              anchors.top: parent.top
              anchors.topMargin: 10
              width: 56
              height: 56
              color: "transparent"
            }
            Text {
              anchors.top: thumb.bottom
              anchors.topMargin: 6
              anchors.horizontalCenter: parent.horizontalCenter
              width: parent.width - 12
              horizontalAlignment: Text.AlignHCenter
              text: card.modelData.name
              color: view.theme.text
              font.family: view.theme.textFontFamily
              font.pixelSize: view.theme.px(11)
              wrapMode: Text.WrapAnywhere
              maximumLineCount: 2
              elide: Text.ElideMiddle
            }
          }

          // A check while it's selected.
          Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.margins: 4
            width: 20
            height: 20
            radius: 10
            visible: card.isSelected
            color: view.theme.accent
            Text {
              anchors.centerIn: parent
              text: "󰄬"
              color: view.theme.background
              font.family: view.theme.fontFamily
              font.pixelSize: 12
            }
          }

          // ×, while the card is under the pointer.
          Rectangle {
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: 4
            width: 20
            height: 20
            radius: 10
            visible: card.hovered || removeMouse.containsMouse
            color: removeMouse.containsMouse ? view.theme.system.red : view.theme.fill("raised")
            Text {
              anchors.centerIn: parent
              text: "󰅖"
              color: view.theme.text
              font.family: view.theme.fontFamily
              font.pixelSize: 12
            }
            MouseArea {
              id: removeMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: view.shelf.remove(card.index)
            }
          }
        }
      }
    }
  }
}
