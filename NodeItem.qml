import QtQuick
import QtQuick.Shapes
import qs.Commons
import "FlowModel.js" as FM

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
  signal dragged(string id, real dxScene, real dyScene)

  readonly property var r: node.rect
  readonly property bool isDecision: node.type === "decision"
  readonly property bool isTerminal: node.type === "start" || node.type === "end"
  readonly property bool isTable: node.type === "table"
  readonly property bool hasSubflow: (node.subflowJson || "").length > 0
  readonly property color tableColor: Qt.rgba(0.31, 0.79, 0.69, 1.0)
  readonly property bool hasMoreColumns: (node.columns ? node.columns.length : 0) > 5
  readonly property int hiddenColumns: (node.columns ? node.columns.length : 0) - displayCols().length

  function displayCols() { return FM.displayColumns(node.columns, 5) }

  readonly property string meta: {
    var a = node.actor || ""
    var c = node.code || ""
    if (a.length > 0 && c.length > 0) return a + "  ·  " + c
    return a.length > 0 ? a : c
  }

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
    case "table": return tableColor
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
    visible: !nodeItem.isDecision && !nodeItem.isTerminal && !nodeItem.isTable
    width: 4
    height: parent.height - 22
    radius: 2
    color: nodeItem.typeAccent()
    anchors.left: parent.left
    anchors.leftMargin: 7
    anchors.verticalCenter: parent.verticalCenter
  }

  // Content is clipped to a padded box so text can never overlap the border,
  // rounded corners, or the diamond edges.
  Item {
    id: content
    anchors.fill: parent
    anchors.leftMargin: nodeItem.isTable ? 0 : (nodeItem.isDecision ? 34 : (nodeItem.isTerminal ? 20 : 16))
    anchors.rightMargin: nodeItem.isTable ? 0 : (nodeItem.isDecision ? 34 : (nodeItem.isTerminal ? 20 : 16))
    anchors.topMargin: nodeItem.isTable ? 0 : (nodeItem.isDecision ? 12 : 9)
    anchors.bottomMargin: nodeItem.isTable ? 0 : (nodeItem.isDecision ? 12 : 9)
    clip: true

    // Tables: a header band + column rows (first 5; the rest in the inspector).
    Column {
      visible: nodeItem.isTable
      anchors { top: parent.top; left: parent.left; right: parent.right }

      Rectangle {
        width: parent.width
        height: 24
        color: Qt.rgba(nodeItem.tableColor.r, nodeItem.tableColor.g, nodeItem.tableColor.b, 0.18)
        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1
          color: Qt.rgba(nodeItem.tableColor.r, nodeItem.tableColor.g, nodeItem.tableColor.b, 0.6) }
        Text {
          anchors.left: parent.left; anchors.leftMargin: 8; anchors.verticalCenter: parent.verticalCenter
          width: parent.width - 70
          text: nodeItem.node.title || nodeItem.node.id
          color: Color.foreground; font.family: Style.font.family; font.pixelSize: 11; font.bold: true
          elide: Text.ElideRight
        }
        Text {
          visible: (nodeItem.node.schema || "").length > 0
          anchors.right: parent.right; anchors.rightMargin: 8; anchors.verticalCenter: parent.verticalCenter
          text: nodeItem.node.schema || ""
          color: Color.muted; font.family: Style.font.family; font.pixelSize: 9
        }
      }

      Repeater {
        model: nodeItem.displayCols()
        delegate: Item {
          required property var modelData
          width: parent.width
          height: 18
          Text {
            anchors.left: parent.left; anchors.leftMargin: 8; anchors.verticalCenter: parent.verticalCenter
            text: modelData.name
            color: Color.foreground; font.family: Style.font.family; font.pixelSize: 10
            elide: Text.ElideRight
            width: parent.width * 0.5
          }
          Row {
            anchors.right: parent.right; anchors.rightMargin: 8; anchors.verticalCenter: parent.verticalCenter
            spacing: 4
            Rectangle {
              visible: modelData.pk === true
              radius: 3; color: Qt.rgba(nodeItem.tableColor.r, nodeItem.tableColor.g, nodeItem.tableColor.b, 0.25)
              implicitWidth: pkText.implicitWidth + 6; implicitHeight: 12
              Text { id: pkText; anchors.centerIn: parent; text: "PK"; color: nodeItem.tableColor
                font.family: Style.font.family; font.pixelSize: 7; font.bold: true }
            }
            Rectangle {
              visible: (modelData.fk || "").length > 0
              radius: 3; color: Qt.rgba(nodeItem.tableColor.r, nodeItem.tableColor.g, nodeItem.tableColor.b, 0.25)
              implicitWidth: fkText.implicitWidth + 6; implicitHeight: 12
              Text { id: fkText; anchors.centerIn: parent; text: "FK"; color: nodeItem.tableColor
                font.family: Style.font.family; font.pixelSize: 7; font.bold: true }
            }
            Text {
              visible: (modelData.type || "").length > 0
              anchors.verticalCenter: parent.verticalCenter
              text: modelData.type || ""
              color: Color.muted; font.family: Style.font.family; font.pixelSize: 9
            }
          }
        }
      }

      Item {
        width: parent.width
        height: 16
        visible: nodeItem.hasMoreColumns
        Text {
          anchors.centerIn: parent
          text: "+" + nodeItem.hiddenColumns + " more column" + (nodeItem.hiddenColumns === 1 ? "" : "s") + " (see details)"
          color: Color.muted; font.family: Style.font.family; font.pixelSize: 8
        }
      }
    }

    // Decisions: only the title and id, centered in the diamond.
    Column {
      visible: nodeItem.isDecision
      anchors.centerIn: parent
      width: parent.width
      spacing: 2
      Text {
        width: parent.width
        text: nodeItem.node.title || nodeItem.node.id
        color: Color.foreground
        font.family: Style.font.family
        font.pixelSize: 12
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
        font.pixelSize: 9
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
      }
    }

    // Other shapes: title/id from the top, meta/subflow pinned to the bottom.
    Column {
      visible: !nodeItem.isDecision && !nodeItem.isTable
      anchors { top: parent.top; left: parent.left; right: parent.right }
      spacing: 2
      Text {
        width: parent.width
        text: nodeItem.node.title || nodeItem.node.id
        color: Color.foreground
        font.family: Style.font.family
        font.pixelSize: 13
        font.bold: true
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        maximumLineCount: nodeItem.isTerminal ? 1 : 2
        wrapMode: Text.WordWrap
      }
      Text {
        width: parent.width
        text: nodeItem.node.id
        color: Color.muted
        font.family: Style.font.family
        font.pixelSize: 9
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
      }
    }

    Text {
      id: metaText
      visible: !nodeItem.isDecision && !nodeItem.isTable && text.length > 0
      anchors {
        left: parent.left
        right: parent.right
        bottom: subflowStrip.visible ? subflowStrip.top : parent.bottom
        bottomMargin: subflowStrip.visible ? 3 : 0
      }
      text: nodeItem.meta
      color: Color.muted
      font.family: Style.font.family
      font.pixelSize: 9
      horizontalAlignment: Text.AlignHCenter
      elide: Text.ElideRight
    }

    Rectangle {
      id: subflowStrip
      visible: !nodeItem.isDecision && !nodeItem.isTable && nodeItem.hasSubflow
      anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
      height: 15
      radius: 4
      color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.20)
      Text {
        anchors.centerIn: parent
        text: "↳ open subflow · " + (nodeItem.node.subflowNodes || 0)
        color: Color.accent
        font.family: Style.font.family
        font.pixelSize: 8
        elide: Text.ElideRight
        width: parent.width - 6
        horizontalAlignment: Text.AlignHCenter
      }
    }
  }

  MouseArea {
    id: hover
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    // Manual drag: pointer is tracked in scene coordinates so moving the node
    // does not feed back into the pointer position (which would stall it).
    property bool pressed: false
    property bool dragged: false
    property point pressScene: Qt.point(0, 0)
    property point lastScene: Qt.point(0, 0)

    onPressed: function(mouse) {
      pressed = true
      dragged = false
      pressScene = mapToItem(null, mouse.x, mouse.y)
      lastScene = pressScene
    }
    onPositionChanged: function(mouse) {
      if (!pressed) return
      var cur = mapToItem(null, mouse.x, mouse.y)
      if (!dragged && (Math.abs(cur.x - pressScene.x) + Math.abs(cur.y - pressScene.y) > 4))
        dragged = true
      if (dragged) {
        nodeItem.dragged(nodeItem.node.id, cur.x - lastScene.x, cur.y - lastScene.y)
        lastScene = cur
      }
    }
    onReleased: pressed = false
    onClicked: {
      if (!dragged) nodeItem.activated(nodeItem.node.id)
      dragged = false
    }
    onDoubleClicked: {
      if (!dragged) nodeItem.opened(nodeItem.node.id)
      dragged = false
    }
  }
}
