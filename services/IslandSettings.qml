import QtQuick
import Quickshell.Io

// The island's own settings, saved to ~/.config/omarchy/island.json and
// changed live from Settings. `values` is the adapter: read and assign its
// properties directly. A missing file is written with the defaults below.
Item {
  id: islandSettings
  required property string home
  readonly property QtObject values: settingsData

  FileView {
    path: islandSettings.home + "/.config/omarchy/island.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onAdapterUpdated: writeAdapter()
    onLoadFailed: function(error) {
      if (error !== FileViewError.FileNotFound) return
      writeAdapter()
      Qt.callLater(reload)
    }
    JsonAdapter {
      id: settingsData
      property real motionScale: 1.5
      property bool clock24h: true
      property bool clockAmPm: false
      property string clockFormat: "short"
      property string hoverStyle: "capsules"
      property bool hoverExpand: hoverStyle === "expand"
      property bool hoverCapsules: hoverStyle === "capsules"
      property string glanceLeft1: "none"
      property string glanceLeft2: "none"
      property string glanceRight1: "weather"
      property string glanceRight2: "volume"
      property bool glanceMediaSatellite: true
      property bool glanceMediaSatelliteBorder: false
      property bool capsuleWorkspaces: true
      property bool capsuleTray: false
      property bool capsuleSystem: false
      property bool capsuleEvent: true
      property string capsuleOrder: "workspaces,media|event,tray,weather,notifications,system"
      property string capsuleEventRange: "any"
      property bool capsuleWeather: true
      property bool capsuleNotifications: false
      property bool capsuleMedia: false
      property bool mediaPill: true
      property string mediaApps: "spotify, feishin"
      property bool volumeHud: true
      property bool brightnessHud: true
      property int bannerSeconds: 8
      property string notificationStyle: "compact"
      property string mutedApps: "omarchy-action"
      property bool notch: false
      property bool reserveTop: true
      // Controls drawn a quarter wide (icon over label); the rest are half.
      property string controlCenterSmall: "bluetooth,focus,awake,night,game,power,keyboard,screensaver,screenshot,dictate,reminder,shelf.shelf,camera.camera,timer.timer,screenrecord,microphoneMute,wifi,calendar.today"
      // What a click on the resting island does, per button (see Island.qml).
      property string leftClick: "activity"
      property string rightClick: "controls"
      property real pillScale: 0.7
      property real topGap: 1
      // A little battery at the resting pill's right end, on a laptop.
      property bool restBattery: true
      property real barGap: 1
      property bool downloads: true
      property bool clipboard: true
      property bool screenRecordingActivity: true
      property bool screenShareActivity: true
      property bool systemUpdates: true
      property bool batteryActivity: true
      property bool bluetoothActivity: true
      property bool networkActivity: true
      property bool playbackOsd: false
      property bool workspaceHud: false
      property bool colorfulSettingsIcons: true
      property bool colorfulLiveActivities: true
      property string textFontMode: "island"
      property string customFont: ""
      property real textScale: 1
      property string controlCenterOrder: "wifi,bluetooth,focus,microphoneMute,awake,night,screenrecord,timer.timer,shelf.shelf,camera.camera,sound,microphone,game,power,keyboard,screensaver,screenshot,dictate,reminder,calendar.today,display"
      property string controlCenterHidden: "game,power,keyboard,night,microphoneMute,calendar.today"
      property bool microphoneMuteControl: false
      property bool stayAwakeControl: true
      property bool screensaverControl: false
      property bool screenshotControl: false
      property bool screenRecordControl: true
      property bool dictateControl: false
      property bool reminderControl: false
      property bool autoHideFullscreen: true
      property bool autoHideTiling: false
      property bool menuApps: true
      // Before Ask AI was an addon; carried over and cleared (see Addons.qml).
      property string askAi: ""
      // Addon id → enabled, and addon id → its options (see addons/Addons.qml).
      property var addons: ({})
      property var addonOptions: ({})
    }
  }
}
