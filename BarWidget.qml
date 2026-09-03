import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "chris.sysmon"

  property int cpuLoad: 0
  property int cpuTemp: -1
  property int gpuLoad: -1
  property int gpuTemp: -1
  property real downloadRate: 0
  property real uploadRate: 0
  readonly property string helperPath: Quickshell.env("HOME") + "/.config/omarchy/plugins/chris.sysmon/sysmon.sh"

  function temperature(value) {
    return value >= 0 ? value + "°" : "--"
  }

  function speed(bytes) {
    if (bytes >= 1073741824) return (bytes / 1073741824).toFixed(1) + "G"
    if (bytes >= 1048576) return (bytes / 1048576).toFixed(1) + "M"
    if (bytes >= 1024) return (bytes / 1024).toFixed(0) + "K"
    return Math.round(bytes) + "B"
  }

  implicitWidth: metrics.implicitWidth + Style.spacing.controlPaddingX * 2
  implicitHeight: barSize

  Row {
    id: metrics
    anchors.centerIn: parent
    spacing: Style.space(8)

    Text {
      text: "CPU " + root.cpuLoad + "% " + root.temperature(root.cpuTemp)
      color: root.bar ? root.bar.barForeground : Color.foreground
      font.family: root.bar ? root.bar.fontFamily : Style.font.family
      font.pixelSize: Style.font.caption
    }

    Text {
      text: "GPU " + (root.gpuLoad >= 0 ? root.gpuLoad + "%" : "--") + " " + root.temperature(root.gpuTemp)
      color: root.bar ? root.bar.barForeground : Color.foreground
      font.family: root.bar ? root.bar.fontFamily : Style.font.family
      font.pixelSize: Style.font.caption
    }

    Text {
      text: "↓" + root.speed(root.downloadRate) + "/s ↑" + root.speed(root.uploadRate) + "/s"
      color: root.bar ? root.bar.barForeground : Color.foreground
      font.family: root.bar ? root.bar.fontFamily : Style.font.family
      font.pixelSize: Style.font.caption
    }
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    onEntered: if (root.bar) root.bar.showTooltip(root, "CPU and GPU utilization/temperature · network download/upload")
    onExited: if (root.bar) root.bar.hideTooltip(root)
  }

  Process {
    id: statsProcess
    command: ["/usr/bin/bash", root.helperPath]
    running: true
    stdout: SplitParser {
      onRead: function(line) {
        const fields = String(line || "").trim().split("\t")
        if (fields.length !== 6) return
        root.cpuLoad = Number(fields[0])
        root.cpuTemp = Number(fields[1])
        root.gpuLoad = Number(fields[2])
        root.gpuTemp = Number(fields[3])
        root.downloadRate = Number(fields[4])
        root.uploadRate = Number(fields[5])
      }
    }
  }
}
