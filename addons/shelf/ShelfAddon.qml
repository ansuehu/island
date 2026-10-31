import QtQuick
import Quickshell.Io
import ".."

// A shelf, as Vorssaint's and NotchNook's: drag files, text, or links onto
// the island (see the DropArea in Island.qml) to park them, then drag them
// back out, click to open (text is copied), or remove them, in the shelf
// view (see ShelfView). Files are kept as references, not copied; the list
// is saved in the addon's options, so it survives a restart of the shell.
Addon {
  id: shelfAddon
  views: [{ name: "shelf", width: 460, padding: 16, component: shelfView }]
  tiles: [{ key: "shelf", title: "Shelf", component: shelfTile }]

  Component {
    id: shelfView
    ShelfView { shelf: shelfAddon; active: shelfAddon.host.view === "shelf" }
  }
  Component {
    id: shelfTile
    ShelfTile { shelf: shelfAddon; center: parent.center }
  }

  // [{ kind: "file" | "link" | "text", value, name }]
  readonly property var items: addon.option("items") || []
  function save(next) { addon.setOption("items", next) }

  function add(drop) {
    var next = items.slice()
    var urls = drop.hasUrls ? drop.urls : []
    for (var i = 0; i < urls.length; i++) next.push(entryFor(String(urls[i])))
    if (!urls.length && drop.hasText && drop.text.trim()) {
      var text = drop.text.trim()
      next.push(/^https?:\/\/\S+$/.test(text) ? entryFor(text) : { kind: "text", value: text, name: text })
    }
    // A thing already parked moves to the end rather than showing twice.
    var seen = {}
    next = next.reverse().filter(function(it) {
      var key = it.kind + ":" + it.value
      if (seen[key]) return false
      return seen[key] = true
    }).reverse()
    save(next)
  }
  function entryFor(url) {
    if (url.indexOf("file://") === 0) {
      var name = url.replace(/\/+$/, "").split("/").pop()
      try { name = decodeURIComponent(name) } catch (e) {}
      return { kind: "file", value: url, name: name }
    }
    return { kind: "link", value: url, name: url.replace(/^https?:\/\/(www\.)?/, "") }
  }
  function remove(index) {
    var next = items.slice()
    next.splice(index, 1)
    save(next)
  }
  function clear() { save([]) }

  // What a drag of these items carries: files and links as one
  // text/uri-list, so a drop gets them all at once, and everything as
  // lines of text for apps that only take text.
  function mimeFor(list) {
    var uris = list.filter(function(it) { return it.kind !== "text" }).map(function(it) { return it.value })
    var mime = { "text/plain": list.map(function(it) { return it.value }).join("\n") }
    if (uris.length) mime["text/uri-list"] = uris.join("\r\n") + "\r\n"
    return mime
  }

  // Files and links open in their default app; text is copied.
  Process { id: runner }
  function activate(item) {
    runner.command = item.kind === "text" ? ["wl-copy", "--", item.value] : ["xdg-open", item.value]
    runner.startDetached()
  }
}
