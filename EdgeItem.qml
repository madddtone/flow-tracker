import QtQuick
import QtQuick.Shapes
import qs.Commons
import "FlowModel.js" as FM

// Renders one directed edge as a cubic curve with an arrow head.
// The root is a world-sized Shape (0,0 origin) so ShapePath can use the
// same absolute coordinates as the node rects.
Shape {
  id: edgeItem
  required property var edge
  required property var sourceNode
  required property var targetNode

  // level: normal | selected | successor | downstream | ancestor | dim
  property string level: "normal"
  property real worldW: 0
  property real worldH: 0

  x: 0
  y: 0
  width: worldW
  height: worldH

  readonly property bool ready: sourceNode !== undefined && sourceNode !== null
    && targetNode !== undefined && targetNode !== null
  readonly property var g: ready ? FM.edgeGeometry(sourceNode, targetNode, edge.back === true)
    : ({ x1: 0, y1: 0, x2: 0, y2: 0, c1x: 0, c1y: 0, c2x: 0, c2y: 0 })
  readonly property var a: ready ? FM.arrow(g, 11)
    : ({ tipX: 0, tipY: 0, leftX: 0, leftY: 0, rightX: 0, rightY: 0 })

  readonly property color lineColor: {
    switch (level) {
    case "selected":
    case "successor": return Color.accent
    case "downstream": return Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.85)
    case "ancestor": return Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.5)
    default: return Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.32)
    }
  }
  readonly property real lineWidth: {
    switch (level) {
    case "selected": return 3.5
    case "successor": return 3
    case "downstream": return 2.4
    case "ancestor": return 1.8
    default: return 1.5
    }
  }
  readonly property real edgeOpacity: level === "dim" ? 0.12 : 1.0
  opacity: edgeOpacity
  Behavior on opacity { NumberAnimation { duration: 120 } }

  ShapePath {
    strokeColor: edgeItem.lineColor
    strokeWidth: edgeItem.lineWidth
    fillColor: "transparent"
    capStyle: ShapePath.RoundCap
    joinStyle: ShapePath.RoundJoin
    startX: edgeItem.g.x1
    startY: edgeItem.g.y1
    PathCubic {
      control1X: edgeItem.g.c1x
      control1Y: edgeItem.g.c1y
      control2X: edgeItem.g.c2x
      control2Y: edgeItem.g.c2y
      x: edgeItem.g.x2
      y: edgeItem.g.y2
    }
  }

  ShapePath {
    strokeColor: "transparent"
    strokeWidth: 0
    fillColor: edgeItem.lineColor
    startX: edgeItem.a.leftX
    startY: edgeItem.a.leftY
    PathLine { x: edgeItem.a.tipX; y: edgeItem.a.tipY }
    PathLine { x: edgeItem.a.rightX; y: edgeItem.a.rightY }
    PathLine { x: edgeItem.a.leftX; y: edgeItem.a.leftY }
  }

  // Condition/label shown when the edge is part of the traced route.
  Text {
    visible: edgeItem.level !== "normal" && edgeItem.level !== "dim"
      && ((edgeItem.edge.when || "").length > 0 || (edgeItem.edge.label || "").length > 0)
    x: (edgeItem.g.c1x + edgeItem.g.c2x) / 2 - width / 2
    y: (edgeItem.g.c1y + edgeItem.g.c2y) / 2 - height / 2
    text: (edgeItem.edge.label && edgeItem.edge.label.length > 0)
      ? edgeItem.edge.label
      : ("when " + edgeItem.edge.when)
    color: Color.foreground
    font.family: Style.font.family
    font.pixelSize: 10
    padding: 2
    Rectangle {
      z: -1
      anchors.fill: parent
      anchors.margins: -3
      radius: 4
      color: Qt.rgba(Color.background.r, Color.background.g, Color.background.b, 0.85)
    }
  }
}
