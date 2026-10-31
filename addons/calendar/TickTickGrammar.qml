import QtQuick
import "../../../io.github.sotoaugusto.ticktick/Model.js" as TTModel

// The TickTick plugin's quick-add grammar, loaded by CalendarView through a
// Loader: without that plugin this file fails to load and the calendar goes
// on with plain titles instead of failing with it.
Item {
  function parse(text) { return TTModel.parseQuickAdd(String(text || "")) }
  function preview(parsed) { return TTModel.quickAddPreview(parsed, false) }
}
