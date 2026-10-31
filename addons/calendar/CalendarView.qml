import QtQuick
import Quickshell.Io
import "../../components"

// The calendar view, as Apple's widget: on the left the selected day's
// weekday, date, and events; on the right its month, Monday first, its weeks
// spread over the same height. As in Apple's Calendar, today is a filled
// accent circle while it's the day shown, and accent numbers once another
// day is picked, that one in a grey circle; a day with events carries a dot
// under its number. Hovering a day previews its agenda without selecting it,
// an event opens its details, and a busy day's hidden events expand in
// place. A day clicked shows its events, as do ←/→ (a day) and ↑/↓ (a week);
// scrolling, dragging, or the chevrons (shown on hover) change the month,
// which slides in from that side. The header's + composes a TickTick task or
// a Google Calendar event for the selected day, and Today comes back to this
// month. Esc steps out of a detail or the composer before closing. It opens
// on today.
Item {
  id: view
  required property var calendar
  property bool active: false
  readonly property var host: view.calendar.host
  readonly property var theme: host.theme
  readonly property color accent: theme.accent

  // White text, Apple style, whatever the theme's text colour.
  readonly property color ink: "#ffffff"
  readonly property color inkMuted: Qt.rgba(1, 1, 1, 0.45)

  readonly property int cell: 34
  // Six weeks' room always, so the island keeps its height from month to
  // month; a month of fewer weeks spreads them over it, as Apple's widget.
  readonly property int gridHeight: 6 * 34
  readonly property int gridWidth: 7 * cell
  // How tall the agenda grows before it scrolls, and the three events that
  // fit beside the month; past that, two and a count of the rest, as Apple's
  // widget.
  readonly property int agendaMax: 168
  readonly property int eventsShown: view.allDayEvents.length > 3 ? 2 : 3

  // What the left pane shows besides the selected day: a hovered day, an
  // event's details, or the composer.
  property var preview: null
  property var detail: null
  property bool composing: false
  property bool expanded: false
  // The next seven days as one list (tasks and events), instead of the month.
  property bool agendaMode: false
  // A task's Delete asks once more before it goes.
  property bool confirmDelete: false
  property string flash: ""
  property string composeError: ""
  // Set when a drag ends, so the release that follows doesn't pick a day.
  property real lastDrag: 0

  readonly property date shownDate: (view.detail || view.composing) ? view.calendar.selected : (view.preview ? view.preview : view.calendar.selected)
  readonly property var allDayEvents: view.calendar.eventsOn(view.shownDate)
  readonly property var dayEvents: view.expanded ? view.allDayEvents : view.allDayEvents.slice(0, view.eventsShown)
  readonly property int hiddenCount: view.allDayEvents.length - view.dayEvents.length
  readonly property bool offMonth: view.calendar.shownYear !== view.calendar.today.getFullYear()
    || view.calendar.shownMonth !== view.calendar.today.getMonth()

  readonly property var weekdays: ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
  readonly property var months: ["January", "February", "March", "April", "May", "June", "July",
    "August", "September", "October", "November", "December"]

  // Where the TickTick plugin's own CLI lives: its quick add is the one write
  // the island makes, so a task lands in the app the bar already uses.
  readonly property string tickTickCli: view.host.home
    + "/.config/omarchy/plugins/io.github.sotoaugusto.ticktick/bin/omarchy-ticktick"
  // The TickTick plugin's quick-add grammar (dates, times, #tags, !priority),
  // when that plugin is installed; without it quick add makes Google events.
  readonly property alias grammar: grammarLoader
  readonly property bool tickTick: grammarLoader.status === Loader.Ready
  Loader { id: grammarLoader; source: "TickTickGrammar.qml" }

  implicitHeight: Math.max(month.y + month.height, left.implicitHeight)

  onActiveChanged: {
    if (!active) return
    view.calendar.viewOpened()
    view.preview = null
    view.detail = null
    view.composing = false
    view.expanded = false
    view.agendaMode = false
    view.confirmDelete = false
    Qt.callLater(function() { view.forceActiveFocus() })
  }
  onPreviewChanged: view.expanded = false
  onDetailChanged: {
    view.confirmDelete = false
    if (view.detail) view.expanded = false
  }
  onComposingChanged: if (view.composing) {
    view.composeError = ""
    Qt.callLater(function() { titleField.focusInput() })
  }

  Keys.onEscapePressed: view.stepBack()
  Keys.onLeftPressed: view.step(-1)
  Keys.onRightPressed: view.step(1)
  Keys.onUpPressed: view.step(-7)
  Keys.onDownPressed: view.step(7)

  // A day picked elsewhere (a click in the grid, an arrow key, the control
  // center tile) closes a detail card; the composer stays, retargeted at the
  // new day.
  Connections {
    target: view.calendar
    function onSelectedChanged() {
      view.preview = null
      view.detail = null
      view.expanded = false
      if (view.composing) Qt.callLater(function() { titleField.focusInput() })
    }
  }

  function step(by) {
    if (view.composing) return
    view.calendar.shiftDay(by)
  }
  function stepBack() {
    if (view.agendaMode && !view.detail && !view.composing) view.agendaMode = false
    else if (view.composing) view.stopCompose()
    else if (view.detail) view.closeDetail()
    else view.host.view = "rest"
  }
  function openDetail(event) {
    view.preview = null
    view.detail = event
    view.composing = false
  }
  function closeDetail() { view.detail = null }
  function startCompose() {
    view.detail = null
    view.composing = true
    titleField.clear()
  }
  function stopCompose() {
    view.composing = false
    view.composeError = ""
  }

  // "Wed 18 Nov"
  function shortDate(day) {
    return view.weekdays[day.getDay()].slice(0, 3) + " " + day.getDate() + " "
      + view.months[day.getMonth()].slice(0, 3)
  }
  function pad(n) { return (n < 10 ? "0" : "") + n }
  // "2026-11-18"
  function stamp(day) {
    return day.getFullYear() + "-" + view.pad(day.getMonth() + 1) + "-" + view.pad(day.getDate())
  }
  function googleDay(day) {
    return "https://calendar.google.com/calendar/r/day/" + day.getFullYear()
      + "/" + view.pad(day.getMonth() + 1) + "/" + view.pad(day.getDate())
  }
  function googleCompose(day, text) {
    var from = day.getFullYear() + view.pad(day.getMonth() + 1) + view.pad(day.getDate())
    var after = new Date(day.getFullYear(), day.getMonth(), day.getDate() + 1)
    var to = after.getFullYear() + view.pad(after.getMonth() + 1) + view.pad(after.getDate())
    return "https://calendar.google.com/calendar/render?action=TEMPLATE&text="
      + encodeURIComponent(String(text || "").trim()) + "&dates=" + from + "/" + to
  }
  // The feed's own link when it has one (TickTick puts the task's in the
  // description), else the day in Google Calendar, which always resolves.
  function eventLink(event) {
    if (!event) return ""
    if (event.url) return event.url
    var found = String(event.description || "").match(/https?:\/\/[^\s<>"]+/)
    if (found) return found[0]
    return view.googleDay(new Date(event.start))
  }
  function linkLabel(event) {
    var link = view.eventLink(event)
    if (link.indexOf("ticktick.com") >= 0) return "Open in TickTick"
    if (link.indexOf("calendar.google.com") >= 0) return "Open in Google Calendar"
    return "Open link"
  }
  function descriptionText(event) {
    if (!event) return ""
    var text = String(event.description || "")
    // A lone link is what the Open button carries, not prose.
    return /^\s*https?:\/\/\S+\s*$/.test(text) ? "" : text
  }

  // ---------- The day ----------

  Item {
    id: left
    visible: !view.agendaMode
    anchors.left: parent.left
    anchors.right: month.left
    anchors.rightMargin: 24
    implicitHeight: view.detail ? detailPane.implicitHeight
      : view.composing ? composePane.implicitHeight
      : agendaPane.implicitHeight

    Column {
      id: agendaPane
      width: parent.width
      visible: !view.detail && !view.composing
      spacing: 0

      Item {
        width: parent.width
        height: weekdayText.height
        Text {
          id: weekdayText
          text: view.weekdays[view.shownDate.getDay()].toUpperCase()
          color: view.accent
          font.family: view.theme.textFontFamily
          font.pixelSize: view.theme.px(13)
          font.weight: Font.Bold
          font.letterSpacing: 0.4
        }
        // To the next seven days as one list.
        Text {
          anchors.right: parent.right
          anchors.baseline: weekdayText.baseline
          text: "7 DAYS"
          color: weekMouse.containsMouse ? view.ink : view.inkMuted
          font.family: view.theme.textFontFamily
          font.pixelSize: view.theme.px(10)
          font.weight: Font.Bold
          font.letterSpacing: 0.4
          MouseArea {
            id: weekMouse
            anchors.fill: parent
            anchors.margins: -5
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: view.agendaMode = true
          }
        }
      }
      Text {
        text: view.shownDate.getDate()
        opacity: view.preview ? 0.8 : 1
        Behavior on opacity { MotionAnimation { theme: view.theme; pace: "standard"; curve: "fade" } }
        color: view.ink
        font.family: view.theme.textFontFamily
        font.pixelSize: view.theme.px(52)
        font.weight: Font.Light
        font.letterSpacing: -1.5
        font.features: { "tnum": 1 }
      }
      Item { width: 1; height: 8 }

      Flickable {
        id: agendaList
        width: parent.width
        height: Math.min(agendaColumn.implicitHeight, view.agendaMax)
        contentWidth: width
        contentHeight: agendaColumn.implicitHeight
        clip: true
        interactive: contentHeight > height
        boundsBehavior: Flickable.StopAtBounds

        Column {
          id: agendaColumn
          width: agendaList.width
          spacing: 6
          Repeater {
            model: view.dayEvents
            delegate: Rectangle {
              required property var modelData
              width: parent.width
              height: eventText.implicitHeight + 12
              radius: 8
              color: view.theme.withAlpha(modelData.color, eventHover.hovered ? 0.3 : 0.18)
              Behavior on color { MotionColorAnimation { theme: view.theme } }
              Rectangle {
                x: 6
                anchors.verticalCenter: parent.verticalCenter
                width: 3
                height: parent.height - 12
                radius: 1.5
                color: modelData.color
              }
              Column {
                id: eventText
                x: 15
                width: parent.width - 21
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1
                Text {
                  width: parent.width
                  text: modelData.title
                  textFormat: Text.PlainText
                  elide: Text.ElideRight
                  color: Qt.lighter(modelData.color, 1.2)
                  font.family: view.theme.textFontFamily
                  font.pixelSize: view.theme.px(13)
                  font.weight: Font.Medium
                  font.letterSpacing: -0.1
                }
                Text {
                  width: parent.width
                  text: view.calendar.spanText(modelData)
                  color: view.theme.withAlpha(Qt.lighter(modelData.color, 1.2), 0.7)
                  font.family: view.theme.textFontFamily
                  font.letterSpacing: view.theme.tracking(view.theme.textFontFamily, view.theme.px(12))
                  font.pixelSize: view.theme.px(12)
                  font.weight: Font.Normal
                  font.features: { "tnum": 1 }
                }
              }
              HoverHandler { id: eventHover }
              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: view.openDetail(modelData)
              }
            }
          }
        }
      }

      // The day's hidden events, opened in place (the list then scrolls).
      Text {
        visible: view.hiddenCount > 0
        topPadding: 6
        text: view.hiddenCount + " more event" + (view.hiddenCount === 1 ? "" : "s")
        color: moreMouse.containsMouse ? view.ink : view.inkMuted
        font.family: view.theme.textFontFamily
        font.letterSpacing: view.theme.tracking(view.theme.textFontFamily, view.theme.px(12))
        font.pixelSize: view.theme.px(12)
        font.weight: Font.Medium
        MouseArea {
          id: moreMouse
          anchors.fill: parent
          anchors.topMargin: 6
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: view.expanded = true
        }
      }
      Text {
        visible: view.expanded && view.allDayEvents.length > view.eventsShown
        topPadding: 6
        text: "Show less"
        color: lessMouse.containsMouse ? view.ink : view.inkMuted
        font.family: view.theme.textFontFamily
        font.letterSpacing: view.theme.tracking(view.theme.textFontFamily, view.theme.px(12))
        font.pixelSize: view.theme.px(12)
        font.weight: Font.Medium
        MouseArea {
          id: lessMouse
          anchors.fill: parent
          anchors.topMargin: 6
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: view.expanded = false
        }
      }
      // Nothing that day, or why there's nothing to show.
      Text {
        id: notice
        readonly property string status: view.calendar.status
        readonly property bool actionable: status === "missing" || status === "offline"
        visible: view.allDayEvents.length === 0
        width: parent.width
        wrapMode: Text.WordWrap
        text: status === "missing" ? "Add a calendar in Settings"
          : status === "offline" ? "Couldn't reach your calendars"
          : status === "loading" ? "Loading…"
          : "No events"
        color: actionable && noticeMouse.containsMouse ? view.ink : view.inkMuted
        font.family: view.theme.textFontFamily
        font.letterSpacing: view.theme.tracking(view.theme.textFontFamily, view.theme.px(13))
        font.pixelSize: view.theme.px(13)
        font.weight: Font.Medium
        font.underline: actionable
        MouseArea {
          id: noticeMouse
          anchors.fill: parent
          enabled: notice.actionable
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: notice.status === "missing"
            ? view.host.openSettings("Addons", view.calendar.addon.id)
            : view.calendar.retry()
        }
      }
      // The quick add's confirmation.
      Row {
        visible: view.flash !== ""
        spacing: 6
        Text {
          height: 16
          verticalAlignment: Text.AlignVCenter
          text: "󰄬"
          color: view.accent
          font.family: view.theme.fontFamily
          font.pixelSize: view.theme.px(13)
        }
        Text {
          height: 16
          verticalAlignment: Text.AlignVCenter
          text: view.flash
          color: view.inkMuted
          font.family: view.theme.textFontFamily
          font.pixelSize: view.theme.px(12)
          font.weight: Font.Medium
        }
      }
    }

    // ---------- One event ----------

    Item {
      id: detailPane
      width: parent.width
      visible: !!view.detail
      implicitHeight: detailColumn.implicitHeight

      Column {
        id: detailColumn
        width: parent.width
        spacing: 0

        Row {
          height: 20
          spacing: 4
          Text {
            width: 18
            text: "󰅁"
            color: backMouse.containsMouse ? view.ink : view.accent
            font.family: view.theme.fontFamily
            font.pixelSize: view.theme.px(15)
            MouseArea {
              id: backMouse
              anchors.fill: parent
              anchors.margins: -4
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: view.closeDetail()
            }
          }
          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "BACK"
            color: view.accent
            font.family: view.theme.textFontFamily
            font.pixelSize: view.theme.px(11)
            font.weight: Font.Bold
            font.letterSpacing: 0.4
            MouseArea {
              anchors.fill: parent
              anchors.margins: -4
              cursorShape: Qt.PointingHandCursor
              onClicked: view.closeDetail()
            }
          }
        }
        Item { width: 1; height: 10 }

        Text {
          width: parent.width
          text: view.detail ? view.detail.title : ""
          color: view.ink
          wrapMode: Text.Wrap
          maximumLineCount: 3
          elide: Text.ElideRight
          font.family: view.theme.textFontFamily
          font.pixelSize: view.theme.px(17)
          font.weight: Font.DemiBold
          font.letterSpacing: -0.2
        }
        Item { width: 1; height: 5 }
        Text {
          width: parent.width
          text: view.detail ? view.shortDate(new Date(view.detail.start)) + " · "
            + view.calendar.spanText(view.detail) : ""
          wrapMode: Text.Wrap
          color: view.inkMuted
          font.family: view.theme.textFontFamily
          font.pixelSize: view.theme.px(12)
          font.weight: Font.Medium
        }
        Item { width: 1; height: 6; visible: !!(view.detail && view.detail.calendar) }
        Row {
          visible: !!(view.detail && view.detail.calendar)
          height: 18
          spacing: 6
          Rectangle {
            width: 7
            height: 7
            radius: 3.5
            y: (parent.height - height) / 2
            color: view.detail ? view.detail.color : "transparent"
          }
          Text {
            width: detailPane.width - 13
            height: parent.height
            verticalAlignment: Text.AlignVCenter
            text: view.detail && view.detail.calendar ? view.detail.calendar : ""
            elide: Text.ElideRight
            color: view.inkMuted
            font.family: view.theme.textFontFamily
            font.pixelSize: view.theme.px(11)
            font.weight: Font.Medium
          }
        }
        Text {
          visible: !!(view.detail && view.detail.location)
          width: parent.width
          topPadding: 6
          text: view.detail && view.detail.location ? "at " + view.detail.location : ""
          wrapMode: Text.Wrap
          color: view.inkMuted
          font.family: view.theme.textFontFamily
          font.pixelSize: view.theme.px(12)
          font.weight: Font.Medium
        }
        Flickable {
          visible: view.descriptionText(view.detail) !== ""
          width: parent.width
          height: Math.min(description.implicitHeight + 8, 72)
          contentWidth: width
          contentHeight: description.implicitHeight
          clip: true
          interactive: contentHeight > height
          boundsBehavior: Flickable.StopAtBounds
          Text {
            id: description
            y: 4
            width: parent.width
            text: view.descriptionText(view.detail)
            wrapMode: Text.Wrap
            color: view.inkMuted
            font.family: view.theme.textFontFamily
            font.pixelSize: view.theme.px(12)
            lineHeight: 1.15
          }
        }
        Item { width: 1; height: 12 }
        Rectangle {
          width: openLabel.implicitWidth + 26
          height: 30
          radius: 15
          color: openMouse.containsMouse ? Qt.lighter(view.accent, 1.1) : view.accent
          Text {
            id: openLabel
            anchors.centerIn: parent
            text: view.linkLabel(view.detail)
            color: view.theme.accentText
            font.family: view.theme.textFontFamily
            font.pixelSize: view.theme.px(12)
            font.weight: Font.DemiBold
          }
          MouseArea {
            id: openMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              var link = view.eventLink(view.detail)
              if (link !== "") Qt.openUrlExternally(link)
            }
          }
        }
        // A TickTick task: done, or gone (asked twice).
        Item { width: 1; height: 8; visible: taskButtons.visible }
        Row {
          id: taskButtons
          visible: !!(view.detail && view.detail.taskId) && view.tickTick
          spacing: 6
          DetailButton {
            label: "󰄬  Complete"
            onActivated: { view.calendar.taskAction(view.detail, "complete"); view.closeDetail() }
          }
          DetailButton {
            label: view.confirmDelete ? "Really delete?" : "󰆴  Delete"
            danger: view.confirmDelete
            onActivated: {
              if (!view.confirmDelete) { view.confirmDelete = true; return }
              view.calendar.taskAction(view.detail, "delete")
              view.closeDetail()
            }
          }
        }
      }
    }

    // ---------- A new task ----------

    Item {
      id: composePane
      width: parent.width
      visible: view.composing
      implicitHeight: composeColumn.implicitHeight

      Column {
        id: composeColumn
        width: parent.width
        spacing: 0

        Row {
          height: 20
          spacing: 4
          Text {
            width: 18
            text: "󰅁"
            color: closeMouse.containsMouse ? view.ink : view.accent
            font.family: view.theme.fontFamily
            font.pixelSize: view.theme.px(15)
            MouseArea {
              id: closeMouse
              anchors.fill: parent
              anchors.margins: -4
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: view.stopCompose()
            }
          }
          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "CANCEL"
            color: view.accent
            font.family: view.theme.textFontFamily
            font.pixelSize: view.theme.px(11)
            font.weight: Font.Bold
            font.letterSpacing: 0.4
            MouseArea {
              anchors.fill: parent
              anchors.margins: -4
              cursorShape: Qt.PointingHandCursor
              onClicked: view.stopCompose()
            }
          }
        }
        Item { width: 1; height: 10 }
        Text {
          text: view.tickTick ? "NEW TASK" : "NEW EVENT"
          color: view.ink
          font.family: view.theme.textFontFamily
          font.pixelSize: view.theme.px(15)
          font.weight: Font.DemiBold
        }
        Text {
          topPadding: 1
          text: (view.tickTick ? "TickTick · " : "Google Calendar · ") + view.shortDate(view.calendar.selected)
          color: view.inkMuted
          font.family: view.theme.textFontFamily
          font.pixelSize: view.theme.px(12)
          font.weight: Font.Medium
        }
        Item { width: 1; height: 10 }
        SearchField {
          id: titleField
          width: parent.width
          host: view.host
          placeholder: view.tickTick ? "Dinner tomorrow 7pm #home !1" : "Event title…"
          onKeyPressed: function(event) {
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
              event.accepted = true
              view.addTask(titleField.text)
            } else if (event.key === Qt.Key_Escape) {
              event.accepted = true
              view.stopCompose()
            }
          }
        }
        Text {
          width: parent.width
          topPadding: 6
          text: view.tickTick ? view.grammar.item.preview(view.parsedTask(titleField.text)) : ""
          visible: text !== ""
          elide: Text.ElideRight
          color: view.inkMuted
          font.family: view.theme.textFontFamily
          font.pixelSize: view.theme.px(11)
          font.weight: Font.Medium
        }
        Item { width: 1; height: 8 }
        Rectangle {
          width: addLabel.implicitWidth + 28
          height: 30
          radius: 15
          color: adder.running ? view.theme.withAlpha(view.accent, 0.6)
            : addTaskMouse.containsMouse ? Qt.lighter(view.accent, 1.1) : view.accent
          Text {
            id: addLabel
            anchors.centerIn: parent
            text: adder.running ? "Adding…" : view.tickTick ? "Add task" : "Add event"
            color: view.theme.accentText
            font.family: view.theme.textFontFamily
            font.pixelSize: view.theme.px(12)
            font.weight: Font.DemiBold
          }
          MouseArea {
            id: addTaskMouse
            anchors.fill: parent
            enabled: !adder.running
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: view.addTask(titleField.text)
          }
        }
        Text {
          visible: view.tickTick
          topPadding: 8
          text: "or a Google Calendar event"
          color: googleMouse.containsMouse ? view.ink : view.inkMuted
          font.family: view.theme.textFontFamily
          font.pixelSize: view.theme.px(11)
          font.weight: Font.Medium
          MouseArea {
            id: googleMouse
            anchors.fill: parent
            anchors.topMargin: 8
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: Qt.openUrlExternally(view.googleCompose(view.calendar.selected, titleField.text))
          }
        }
        Text {
          visible: view.composeError !== ""
          width: parent.width
          topPadding: 8
          text: view.composeError
          wrapMode: Text.Wrap
          color: view.theme.system.red
          font.family: view.theme.textFontFamily
          font.pixelSize: view.theme.px(11)
          font.weight: Font.Medium
        }
      }
    }
  }

  // The write itself, through the TickTick plugin's CLI. Its answer is JSON
  // on success and a plain message on failure.
  Process {
    id: adder
    property var args: []
    property var parsed: null
    command: [view.tickTickCli].concat(adder.args)
    stderr: StdioCollector { id: adderError; waitForEnd: true }
    onExited: function(code) {
      if (code !== 0) {
        var message = String(adderError.text || "").trim()
        view.composeError = message !== "" ? message : "Couldn't add the task"
        return
      }
      view.composing = false
      if (adder.parsed) view.calendar.addPending(adder.parsed.title, adder.parsed.due, adder.parsed.time)
      view.flash = "Added to TickTick"
      flashTimer.restart()
      // TickTick's feed trails a write by up to a minute; read it every 15 s
      // until the task shows up or two minutes pass.
      refreshTimer.tries = 0
      refreshTimer.restart()
    }
  }
  Timer {
    id: flashTimer
    interval: 2600
    onTriggered: view.flash = ""
  }
  Timer {
    id: refreshTimer
    interval: 15000
    repeat: true
    property int tries: 0
    onTriggered: {
      view.calendar.retry()
      if (++tries >= 8) stop()
    }
  }

  // The TickTick plugin's parse of the line; a line naming no day lands on
  // the selected one.
  function parsedTask(text) {
    var parsed = view.grammar.item ? view.grammar.item.parse(text)
      : { title: String(text || "").trim(), due: "", dueGiven: false, time: "", priority: 0, tags: [] }
    if (!parsed.dueGiven) parsed.due = view.stamp(view.calendar.selected)
    // The CLI takes the day words too; the calendar wants the date.
    var shift = { yesterday: -1, today: 0, tomorrow: 1 }[String(parsed.due).toLowerCase()]
    if (shift !== undefined) {
      var now = view.calendar.today
      parsed.due = view.stamp(new Date(now.getFullYear(), now.getMonth(), now.getDate() + shift))
    }
    return parsed
  }
  function addTask(text) {
    if (!view.tickTick) { Qt.openUrlExternally(view.googleCompose(view.calendar.selected, text)); return }
    var parsed = view.parsedTask(text)
    if (parsed.title === "") { view.composeError = "Type a title first"; return }
    if (adder.running) return
    view.composeError = ""
    var args = ["add", parsed.title, "--due", parsed.due]
    if (parsed.time) args = args.concat(["--time", parsed.time])
    if (parsed.priority > 0) args = args.concat(["--priority", String(parsed.priority)])
    if (parsed.tags.length > 0) args = args.concat(["--tags", parsed.tags.join(",")])
    adder.args = args
    adder.parsed = parsed
    adder.running = true
  }

  // ---------- The month ----------

  Item {
    id: month
    visible: !view.agendaMode
    anchors.right: parent.right
    width: view.gridWidth
    height: grid.y + view.gridHeight

    readonly property var first: new Date(view.calendar.shownYear, view.calendar.shownMonth, 1)
    // Blank cells before the 1st, Monday first.
    readonly property int lead: (first.getDay() + 6) % 7
    readonly property int length: new Date(view.calendar.shownYear, view.calendar.shownMonth + 1, 0).getDate()
    readonly property int weeks: Math.ceil((lead + length) / 7)
    readonly property real rowHeight: view.gridHeight / weeks

    // A month changed slides in from the side it's on, as the old fades.
    property int lastIndex: view.calendar.shownYear * 12 + view.calendar.shownMonth
    readonly property int index: view.calendar.shownYear * 12 + view.calendar.shownMonth
    onIndexChanged: {
      view.preview = null
      var by = index > lastIndex ? 1 : -1
      lastIndex = index
      slide.stop()
      slideIn.from = 14 * by
      slide.start()
    }
    ParallelAnimation {
      id: slide
      NumberAnimation { id: slideIn; target: grid; property: "x"; to: 0; duration: view.theme.motionDuration("expressive"); easing.type: Easing.BezierSpline; easing.bezierCurve: view.theme.motionCurve("settle") }
      NumberAnimation { target: grid; property: "opacity"; from: 0.2; to: 1; duration: view.theme.motionDuration("standard"); easing.type: Easing.BezierSpline; easing.bezierCurve: view.theme.motionCurve("settle") }
    }
    HoverHandler { id: monthHover }

    Text {
      id: monthName
      x: (view.cell - 14) / 2
      text: view.months[view.calendar.shownMonth].toUpperCase()
        + (view.calendar.shownYear !== view.calendar.today.getFullYear() ? " " + view.calendar.shownYear : "")
      color: view.accent
      font.family: view.theme.textFontFamily
      font.pixelSize: view.theme.px(13)
      font.weight: Font.Bold
      font.letterSpacing: 0.4
    }
    Row {
      anchors.right: parent.right
      anchors.verticalCenter: monthName.verticalCenter
      spacing: 0
      opacity: monthHover.hovered || view.offMonth ? 1 : 0.5
      Behavior on opacity { MotionAnimation { theme: view.theme; pace: "fade"; curve: "fade" } }

      // Back to this month, when looking at another.
      Text {
        visible: view.offMonth
        width: 34
        horizontalAlignment: Text.AlignHCenter
        text: "TODAY"
        color: todayMouse.containsMouse ? view.ink : view.accent
        font.family: view.theme.textFontFamily
        font.pixelSize: view.theme.px(10)
        font.weight: Font.Bold
        font.letterSpacing: 0.3
        MouseArea {
          id: todayMouse
          anchors.fill: parent
          anchors.margins: -2
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: view.calendar.selectToday()
        }
      }
      // Read the calendars again now; it spins while they load.
      Text {
        id: syncGlyph
        width: 26
        horizontalAlignment: Text.AlignHCenter
        text: "󰑐"
        color: syncMouse.containsMouse || view.calendar.fetching ? view.ink : view.inkMuted
        font.family: view.theme.fontFamily
        font.pixelSize: view.theme.px(14)
        RotationAnimator on rotation {
          from: 0; to: 360; duration: 900
          loops: Animation.Infinite
          running: view.calendar.fetching
          onRunningChanged: if (!running) syncGlyph.rotation = 0
        }
        MouseArea {
          id: syncMouse
          anchors.fill: parent
          anchors.margins: -3
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: view.calendar.retry()
        }
      }
      // A task or event for the selected day.
      Text {
        width: 26
        horizontalAlignment: Text.AlignHCenter
        text: "󰐕"
        color: addMouse.containsMouse ? view.ink : view.inkMuted
        font.family: view.theme.fontFamily
        font.pixelSize: view.theme.px(15)
        MouseArea {
          id: addMouse
          anchors.fill: parent
          anchors.margins: -3
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: view.startCompose()
        }
      }
      Repeater {
        model: [{ glyph: "󰅁", by: -1 }, { glyph: "󰅂", by: 1 }]
        delegate: Text {
          scale: chevronMouse.pressed ? 0.88 : 1
          Behavior on scale { MotionAnimation { theme: view.theme; pace: chevronMouse.pressed ? "press" : "standard" } }
          required property var modelData
          width: 26
          horizontalAlignment: Text.AlignHCenter
          text: modelData.glyph
          color: chevronMouse.containsMouse ? view.ink : view.inkMuted
          font.family: view.theme.fontFamily
          font.pixelSize: view.theme.px(16)
          MouseArea {
            id: chevronMouse
            anchors.fill: parent
            anchors.margins: -3
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: view.calendar.shiftMonth(parent.modelData.by)
          }
        }
      }
    }

    Row {
      id: weekdayRow
      y: monthName.height + 12
      Repeater {
        model: ["M", "T", "W", "T", "F", "S", "S"]
        delegate: Text {
          required property string modelData
          required property int index
          width: view.cell
          horizontalAlignment: Text.AlignHCenter
          text: modelData
          color: index >= 5 ? view.inkMuted : view.ink
          font.family: view.theme.textFontFamily
          font.letterSpacing: view.theme.tracking(view.theme.textFontFamily, view.theme.px(13))
          font.pixelSize: view.theme.px(13)
          font.weight: Font.Normal
        }
      }
    }

    Item {
      id: grid
      y: weekdayRow.y + weekdayRow.height + 6
      width: parent.width
      height: view.gridHeight

      // A drag moves a day per column, so a flick crosses a week and spills
      // into the next month. A click that never drags stays a click.
      DragHandler {
        id: gridDrag
        target: null
        xAxis.enabled: true
        yAxis.enabled: false
        dragThreshold: 12
        property real travelled: 0
        onActiveChanged: {
          if (active) { travelled = 0; return }
          var by = Math.round(-travelled / view.cell)
          if (by === 0) return
          view.lastDrag = Date.now()
          view.calendar.shiftDay(by)
        }
        onActiveTranslationChanged: if (active) travelled = activeTranslation.x
      }

      Repeater {
        model: month.length
        delegate: Item {
          id: day
          required property int index
          readonly property int slot: month.lead + index
          readonly property date date: new Date(view.calendar.shownYear, view.calendar.shownMonth, index + 1)
          readonly property bool isToday: view.calendar.sameDay(date, view.calendar.today)
          readonly property bool isSelected: view.calendar.sameDay(date, view.calendar.selected)
          readonly property bool hasEvents: view.calendar.hasEventsOn(date)
          readonly property var dotColors: view.calendar.dotColorsOn(date)
          x: (slot % 7) * view.cell
          y: Math.floor(slot / 7) * month.rowHeight
          width: view.cell
          height: month.rowHeight

          Rectangle {
            id: dayCircle
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -2
            width: 26
            height: 26
            radius: 13
            color: day.isSelected ? (day.isToday ? view.accent : Qt.rgba(1, 1, 1, 0.2))
              : dayMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
            scale: day.isSelected ? 1 : 0.9
            Behavior on color { MotionColorAnimation { theme: view.theme } }
            Behavior on scale { MotionAnimation { theme: view.theme; pace: "expressive" } }
          }
          Text {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -2
            text: day.index + 1
            color: day.isToday ? (day.isSelected ? view.theme.accentText : view.accent)
              : day.slot % 7 >= 5 ? view.inkMuted : view.ink
            font.family: view.theme.textFontFamily
            font.letterSpacing: view.theme.tracking(view.theme.textFontFamily, view.theme.px(13))
            font.pixelSize: view.theme.px(13)
            font.weight: day.isToday ? Font.DemiBold : Font.Normal
            font.features: { "tnum": 1 }
          }
          // A day with something on it, as Apple's month view: a dot under
          // the number, in the accent, or in the circle's text colour when
          // that day is the filled one.
          Row {
            visible: day.hasEvents
            anchors.horizontalCenter: parent.horizontalCenter
            y: dayCircle.y + dayCircle.height + 1.5
            spacing: 2
            opacity: day.slot % 7 >= 5 && !day.isSelected ? 0.6 : 1
            Repeater {
              model: day.dotColors
              delegate: Rectangle {
                required property var modelData
                width: 3.5
                height: 3.5
                radius: 1.75
                color: modelData
              }
            }
          }
          MouseArea {
            id: dayMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onContainsMouseChanged: {
              if (containsMouse) view.preview = day.date
              else if (view.preview && view.calendar.sameDay(view.preview, day.date)) view.preview = null
            }
            onClicked: {
              // The release after a drag isn't a pick.
              if (Date.now() - view.lastDrag < 250) return
              view.calendar.select(day.date)
            }
          }
        }
      }
    }

    // A notch of the wheel is a month; sideways, a day.
    WheelHandler {
      property real held: 0
      property real heldX: 0
      acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
      onWheel: function(event) {
        var dx = event.angleDelta.x, dy = event.angleDelta.y
        if (Math.abs(dx) > Math.abs(dy)) {
          heldX += dx
          if (Math.abs(heldX) < 120) return
          view.calendar.shiftDay(heldX > 0 ? 1 : -1)
          heldX = 0
          return
        }
        held += dy
        if (Math.abs(held) < 120) return
        view.calendar.shiftMonth(held > 0 ? -1 : 1)
        held = 0
      }
    }
  }

  // ---------- The next seven days ----------

  readonly property var weekDays: {
    var t = view.calendar.today, days = []
    for (var i = 0; i < 7; i++) {
      var day = new Date(t.getFullYear(), t.getMonth(), t.getDate() + i)
      days.push({ date: day, events: view.calendar.eventsOn(day) })
    }
    return days
  }
  function dayLabel(day, index) {
    if (index === 0) return "TODAY"
    if (index === 1) return "TOMORROW"
    return view.weekdays[day.getDay()].toUpperCase() + " " + day.getDate()
  }
  // A row clicked: back to the month on its day, with its details open.
  function showFromAgenda(day, event) {
    view.agendaMode = false
    view.calendar.select(day)
    Qt.callLater(function() { view.openDetail(event) })
  }

  Item {
    id: agenda
    anchors.fill: parent
    visible: view.agendaMode
    Text {
      id: agendaTitle
      text: "NEXT 7 DAYS"
      color: view.accent
      font.family: view.theme.textFontFamily
      font.pixelSize: view.theme.px(13)
      font.weight: Font.Bold
      font.letterSpacing: 0.4
    }
    Text {
      anchors.right: parent.right
      anchors.baseline: agendaTitle.baseline
      text: "MONTH"
      color: monthLinkMouse.containsMouse ? view.ink : view.inkMuted
      font.family: view.theme.textFontFamily
      font.pixelSize: view.theme.px(10)
      font.weight: Font.Bold
      font.letterSpacing: 0.4
      MouseArea {
        id: monthLinkMouse
        anchors.fill: parent
        anchors.margins: -5
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: view.agendaMode = false
      }
    }
    Flickable {
      id: agendaScroll
      anchors.top: agendaTitle.bottom
      anchors.topMargin: 10
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.bottom: agendaError.visible ? agendaError.top : parent.bottom
      contentWidth: width
      contentHeight: agendaDays.implicitHeight
      clip: true
      boundsBehavior: Flickable.StopAtBounds
      Column {
        id: agendaDays
        width: agendaScroll.width
        spacing: 12
        Repeater {
          model: view.weekDays
          delegate: Column {
            id: agendaDay
            required property var modelData
            required property int index
            width: agendaDays.width
            spacing: 5
            Text {
              text: view.dayLabel(agendaDay.modelData.date, agendaDay.index)
              color: agendaDay.index === 0 ? view.accent : view.inkMuted
              font.family: view.theme.textFontFamily
              font.pixelSize: view.theme.px(11)
              font.weight: Font.Bold
              font.letterSpacing: 0.4
            }
            Text {
              visible: agendaDay.modelData.events.length === 0
              text: "Nothing"
              color: Qt.rgba(1, 1, 1, 0.3)
              font.family: view.theme.textFontFamily
              font.pixelSize: view.theme.px(12)
            }
            Repeater {
              model: agendaDay.modelData.events
              delegate: Rectangle {
                id: agendaRow
                required property var modelData
                readonly property bool task: !!modelData.taskId && view.tickTick
                width: agendaDay.width
                height: 34
                radius: 8
                color: view.theme.withAlpha(modelData.color, agendaRowMouse.containsMouse ? 0.3 : 0.18)
                MouseArea {
                  id: agendaRowMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: view.showFromAgenda(agendaDay.modelData.date, agendaRow.modelData)
                }
                // A task's checkbox; an event's colour bar.
                Rectangle {
                  x: agendaRow.task ? 9 : 6
                  anchors.verticalCenter: parent.verticalCenter
                  width: agendaRow.task ? 16 : 3
                  height: agendaRow.task ? 16 : parent.height - 12
                  radius: agendaRow.task ? 8 : 1.5
                  color: agendaRow.task ? (checkMouse.containsMouse ? agendaRow.modelData.color : "transparent") : agendaRow.modelData.color
                  border.width: agendaRow.task ? 1.5 : 0
                  border.color: agendaRow.modelData.color
                  Text {
                    anchors.centerIn: parent
                    visible: agendaRow.task && checkMouse.containsMouse
                    text: "󰄬"
                    color: "#000000"
                    font.family: view.theme.fontFamily
                    font.pixelSize: 11
                  }
                  MouseArea {
                    id: checkMouse
                    enabled: agendaRow.task
                    anchors.fill: parent
                    anchors.margins: -5
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: view.calendar.taskAction(agendaRow.modelData, "complete")
                  }
                }
                Text {
                  x: agendaRow.task ? 34 : 15
                  anchors.verticalCenter: parent.verticalCenter
                  width: parent.width - x - agendaTime.width - (trash.visible ? 34 : 14)
                  text: agendaRow.modelData.title
                  textFormat: Text.PlainText
                  elide: Text.ElideRight
                  color: Qt.lighter(agendaRow.modelData.color, 1.2)
                  font.family: view.theme.textFontFamily
                  font.pixelSize: view.theme.px(13)
                  font.weight: Font.Medium
                }
                Text {
                  id: agendaTime
                  anchors.right: trash.visible ? trash.left : parent.right
                  anchors.rightMargin: trash.visible ? 6 : 10
                  anchors.verticalCenter: parent.verticalCenter
                  text: view.calendar.spanText(agendaRow.modelData)
                  color: view.theme.withAlpha(Qt.lighter(agendaRow.modelData.color, 1.2), 0.7)
                  font.family: view.theme.textFontFamily
                  font.pixelSize: view.theme.px(11)
                  font.features: { "tnum": 1 }
                }
                // Delete, while hovered: a first click arms it (red), a
                // second deletes.
                Text {
                  id: trash
                  property bool armed: false
                  visible: agendaRow.task && (agendaRowMouse.containsMouse || trashMouse.containsMouse || armed)
                  anchors.right: parent.right
                  anchors.rightMargin: 10
                  anchors.verticalCenter: parent.verticalCenter
                  text: "󰆴"
                  color: armed ? view.theme.system.red : trashMouse.containsMouse ? view.ink : view.inkMuted
                  font.family: view.theme.fontFamily
                  font.pixelSize: view.theme.px(14)
                  MouseArea {
                    id: trashMouse
                    anchors.fill: parent
                    anchors.margins: -5
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                      if (!trash.armed) { trash.armed = true; return }
                      view.calendar.taskAction(agendaRow.modelData, "delete")
                    }
                    onExited: trash.armed = false
                  }
                }
              }
            }
          }
        }
      }
    }
    Text {
      id: agendaError
      visible: view.calendar.taskError !== ""
      anchors.bottom: parent.bottom
      width: parent.width
      text: view.calendar.taskError
      wrapMode: Text.Wrap
      color: view.theme.system.red
      font.family: view.theme.textFontFamily
      font.pixelSize: view.theme.px(11)
    }
  }

  component DetailButton: Rectangle {
    id: detailButton
    property string label: ""
    property bool danger: false
    signal activated()
    width: detailButtonText.implicitWidth + 24
    height: 28
    radius: 14
    color: danger ? view.theme.system.red : detailButtonMouse.containsMouse ? view.theme.fill("strong") : view.theme.fill("raised")
    Text {
      id: detailButtonText
      anchors.centerIn: parent
      text: detailButton.label
      color: "#ffffff"
      font.family: view.theme.fontFamily
      font.pixelSize: view.theme.px(12)
    }
    MouseArea {
      id: detailButtonMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: detailButton.activated()
    }
  }
}
