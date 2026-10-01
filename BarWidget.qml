import QtQuick
import Quickshell
import qs.Commons
import qs.Ui

// Bar icon for Flow Tracker. Clicking it toggles the fullscreen canvas
// overlay (the same overlay the SUPER + CTRL + G binding opens).
BarWidget {
  id: root
  moduleName: "io.github.madddtone.flow-tracker"

  // Follow the Omarchy theme: the bar's own foreground/active colors, which
  // track Color.bar.text / Color.bar.active and animate on theme change.
  readonly property color iconColor: root.bar ? root.bar.barForeground : Color.bar.text
  readonly property color iconActiveColor: root.bar ? root.bar.urgent : Color.bar.active

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function launch() {
    if (root.bar && root.bar.shell && typeof root.bar.shell.toggle === "function") {
      root.bar.shell.toggle(root.moduleName, "{}")
      return
    }
    Quickshell.execDetached(["omarchy-shell", "shell", "toggle", root.moduleName])
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "\uf0e8"
    fontSize: Style.font.title
    foreground: root.iconColor
    activeColor: root.iconActiveColor
    tooltipText: "Flow Tracker\nClick to open the flow canvas"
    onPressed: function(buttonCode) { root.launch() }
  }
}
