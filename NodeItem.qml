import QtQuick
import QtQuick.Shapes
import qs.Commons

// Renders a single flow node. Coordinates/size come from the compiled
// node.rect; the parent delegates position it in world space.
Item {
  id: nodeItem
  required property var node
  property bool isSelected: false
  property bool isSuccessor: false
  property bool isDownstream: false
  property bool isAncestor: false
  property bool isDim: false

  signal activated(string id)
  signal opened(string id)

  readonly property var r: node.rect
  readonly property bool isDecision: node.type === "decision"
  readonly property bool isTerminal: node.type === "start" || node.type === "end"

  width: r.w
  height: r.h
  opacity: isDim ? 0.22 : 1.0
  Behavior on opacity { NumberAnimation { duration: 120 } }

  readonly property color baseFill: Color.menu.background
  readonly property color baseBorder: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.30)
  readonly property color ringColor: isSelected ? Color.accent
    : isSuccessor ? Qt.lighter(Color.accent, 1.35)
    : isDownstream ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.75)
    : isAncestor ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.55)
    : baseBorder
  readonly property int ringWidth: isSelected ? 3 : (isSuccessor || isDownstream || isAncestor) ? 2 : 1

  function typeAccent() {
    switch (node.type) {
    case "start": return Qt.lighter(Color.accent, 1.2)
    case "end": return Color.accent
    case "decision": return Color.urgent
    case "subflow": return Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.85)
    case "external": return Color.muted
    default: return Color.foreground
    }
  }

  // Glow behind highlighted nodes.
  Rectangle {
    anchors.centerIn: parent
    width: parent.width + 14
    height: parent.height + 14
    radius: 16
    visible: nodeItem.isSelected || nodeItem.isSuccessor || nodeItem.isDownstream
    color: Qt.rgba(nodeItem.ringColor.r, nodeItem.ringColor.g, nodeItem.ringColor.b, 0.12)
  }

  // Card background (rectangle).
  Rectangle {
    id: card
    anchors.fill: parent
    visible: !nodeItem.isDecision
    radius: nodeItem.isTerminal ? height / 2 : 12
    color: nodeItem.baseFill
    border.width: nodeItem.ringWidth
    border.color: nodeItem.ringColor
    Behavior on border.color { ColorAnimation { duration: 120 } }
  }

  // Diamond background (decision).
  Shape {
    anchors.fill: parent
    visible: nodeItem.isDecision
    ShapePath {
      strokeColor: nodeItem.ringColor
      strokeWidth: nodeItem.ringWidth
      fillColor: nodeItem.baseFill
      startX: nodeItem.width / 2
      startY: 4
      PathLine { x: nodeItem.width - 4; y: nodeItem.height / 2 }
      PathLine { x: nodeItem.width / 2; y: nodeItem.height - 4 }
      PathLine { x: 4; y: nodeItem.height / 2 }
      PathLine { x: nodeItem.width / 2; y: 4 }
    }
  }

  // Type stripe for non-decision, non-terminal cards.
  Rectangle {
    visible: !nodeItem.isDecision && !nodeItem.isTerminal
    width: 4
    height: parent.height - 20
    radius: 2
    color: nodeItem.typeAccent()
    anchors.left: parent.left
    anchors.leftMargin: 7
    anchors.verticalCenter: parent.verticalCenter
  }

  Column {
    anchors.centerIn: parent
    width: parent.width - (nodeItem.isDecision ? 34 : (nodeItem.isTerminal ? 20 : 24))
    spacing: 3

    Text {
      width: parent.width
      text: nodeItem.node.title || nodeItem.node.id
      color: Color.foreground
      font.family: Style.font.family
      font.pixelSize: 14
      font.bold: true
      horizontalAlignment: Text.AlignHCenter
      elide: Text.ElideRight
      maximumLineCount: 2
      wrapMode: Text.WordWrap
    }

    Text {
      width: parent.width
      text: nodeItem.node.id
      color: Color.muted
      font.family: Style.font.family
      font.pixelSize: 10
      horizontalAlignment: Text.AlignHCenter
      elide: Text.ElideRight
    }

    Row {
      anchors.horizontalCenter: parent.horizontalCenter
      spacing: 6
      visible: (nodeItem.node.actor || "").length > 0 || (nodeItem.node.code || "").length > 0

      Text {
        visible: (nodeItem.node.actor || "").length > 0
        text: nodeItem.node.actor || ""
        color: nodeItem.typeAccent()
        font.family: Style.font.family
        font.pixelSize: 9
      }
      Text {
        visible: (nodeItem.node.actor || "").length > 0 && (nodeItem.node.code || "").length > 0
        text: "·"
        color: Color.muted
        font.pixelSize: 9
      }
      Text {
        visible: (nodeItem.node.code || "").length > 0
        text: nodeItem.node.code || ""
        color: Color.muted
        font.family: Style.font.family
        font.pixelSize: 9
        elide: Text.ElideMiddle
        width: Math.min(implicitWidth, parent.parent.width - 10)
      }
    }
  }

  MouseArea {
    id: hover
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: nodeItem.activated(nodeItem.node.id)
    onDoubleClicked: nodeItem.opened(nodeItem.node.id)
  }

  // Subflow affordance: double-click (or Enter / the inspector button) drills in.
  Rectangle {
    visible: (nodeItem.node.subflowJson || "").length > 0
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.margins: 5
    radius: 4
    color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.22)
    implicitWidth: subflowText.implicitWidth + 10
    implicitHeight: 13
    Text {
      id: subflowText
      anchors.centerIn: parent
      text: "↳ " + (nodeItem.node.subflowNodes || 0)
      color: Color.accent
      font.family: Style.font.family
      font.pixelSize: 8
    }
  }
}
