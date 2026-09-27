import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "io.github.najibninaba.inline"
  manageIpc: false

  property bool enabled: false
  property bool daemonRunning: false
  property string model: "unknown"
  property string statusOutput: ""

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  function refresh() {
    if (!statusProcess.running) {
      statusOutput = ""
      statusProcess.running = true
    }
  }

  function toggleCompletion() {
    Quickshell.execDetached(["omarchy-inline", "toggle"])
    refreshLater.restart()
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight
  Component.onCompleted: refresh()
  onOpenedChanged: if (opened) refresh()

  Process {
    id: statusProcess
    command: ["omarchy-inline", "status", "--json"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.statusOutput = String(text || "").trim()
    }
    onExited: function() {
      try {
        var status = JSON.parse(root.statusOutput)
        root.enabled = Boolean(status.enabled)
        root.daemonRunning = status.daemon === "running"
        root.model = String(status.model || "unknown")
      } catch (error) {
        root.daemonRunning = false
      }
    }
  }

  Timer {
    id: refreshLater
    interval: 250
    repeat: false
    onTriggered: root.refresh()
  }

  Timer {
    interval: 5000
    repeat: true
    running: true
    onTriggered: root.refresh()
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰘦"
    dimmed: !root.enabled || !root.daemonRunning
    tooltipText: "Inline: " + (root.enabled ? "Enabled" : "Disabled")
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.RightButton) root.toggleCompletion()
      else root.toggle()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(360))
    contentHeight: panel.fittedContentHeight(content.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onActivateRequested: root.toggleCompletion()
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: content
        width: parent.width
        spacing: Style.space(12)

        PanelHero {
          width: parent.width
          title: "Inline"
          meta: root.daemonRunning ? (root.enabled ? "Enabled" : "Paused") : "Daemon stopped"
          foreground: root.foreground
          fontFamily: root.fontFamily
          iconComponent: Component {
            Text {
              text: "󰘦"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.display
              horizontalAlignment: Text.AlignHCenter
              verticalAlignment: Text.AlignVCenter
            }
          }
          trailingControl: Component {
            ToggleSwitch {
              checked: root.enabled
              enabled: root.daemonRunning
              foreground: root.foreground
              onToggled: root.toggleCompletion()
            }
          }
        }

        PanelSeparator { foreground: root.foreground }

        Text {
          width: parent.width
          text: "Model: " + root.model
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          horizontalAlignment: Text.AlignHCenter
          wrapMode: Text.Wrap
        }

        Text {
          width: parent.width
          text: "GUI: Tab accepts the next word. Bash: Alt+Right accepts the next word; Tab keeps normal completion."
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          horizontalAlignment: Text.AlignHCenter
          wrapMode: Text.Wrap
        }
      }
    }
  }
}
