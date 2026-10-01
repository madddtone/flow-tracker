import QtQuick
import QtQuick.Controls
import qs.Commons

// Right-hand attribute inspector for the selected node.
Rectangle {
  id: inspector
  property var node: null
  property var edges: []
  property var byId: ({})
  signal closeRequested()
  signal goTo(string id)

  color: Color.menu.background
  border.width: 1
  border.color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.18)

  function titleCase(s) {
    var parts = String(s || "").split(" ")
    for (var i = 0; i < parts.length; i++)
      if (parts[i].length > 0) parts[i] = parts[i][0].toUpperCase() + parts[i].slice(1)
    return parts.join(" ")
  }

  function outgoing(id) {
    var out = []
    for (var i = 0; i < edges.length; i++) if (edges[i].from === id) out.push(edges[i])
    return out
  }

  Flickable {
    id: flick
    anchors.fill: parent
    anchors.margins: 18
    contentWidth: width
    contentHeight: body.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    ScrollBar.vertical: ScrollBar {}

    Column {
      id: body
      width: flick.width
      spacing: 10

      Row {
        width: parent.width
        spacing: 8
        Text {
          width: parent.width - closeBtn.width - 8
          text: inspector.node ? (inspector.node.title || inspector.node.id) : ""
          color: Color.foreground
          font.family: Style.font.family
          font.pixelSize: 18
          font.bold: true
          wrapMode: Text.WordWrap
        }
        Rectangle {
          id: closeBtn
          width: 24; height: 24; radius: 6
          color: closeMa.containsMouse ? Color.menu.selectedBackground : "transparent"
          Text { anchors.centerIn: parent; text: "\u2715"; color: Color.muted; font.pixelSize: 13 }
          MouseArea {
            id: closeMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: inspector.closeRequested()
          }
        }
      }

      Row {
        spacing: 8
        Rectangle {
          radius: 5
          color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.16)
          border.width: 1
          border.color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.5)
          implicitWidth: typeText.implicitWidth + 14
          implicitHeight: typeText.implicitHeight + 6
          Text {
            id: typeText
            anchors.centerIn: parent
            text: inspector.node ? inspector.node.type : ""
            color: Color.accent
            font.family: Style.font.family
            font.pixelSize: 10
            font.bold: true
          }
        }
        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: inspector.node ? inspector.node.id : ""
          color: Color.muted
          font.family: Style.font.family
          font.pixelSize: 11
        }
      }

      Repeater {
        model: {
          if (!inspector.node) return []
          var n = inspector.node
          var rows = []
          if (n.actor) rows.push(["Actor", n.actor])
          if (n.owner) rows.push(["Owner", n.owner])
          if (n.status) rows.push(["Status", n.status])
          if (n.priority) rows.push(["Priority", n.priority])
          if (n.code) rows.push(["Code", n.code])
          if (n.tags && n.tags.length) rows.push(["Tags", n.tags.join(", ")])
          if (n.subflow) rows.push(["Subflow", n.subflow])
          return rows
        }
        delegate: Row {
          required property var modelData
          width: body.width
          spacing: 8
          Text {
            text: modelData[0]
            color: Color.muted
            font.family: Style.font.family
            font.pixelSize: 11
            width: 64
          }
          Text {
            width: body.width - 72
            text: modelData[1]
            color: Color.foreground
            font.family: Style.font.family
            font.pixelSize: 12
            wrapMode: Text.Wrap
          }
        }
      }

      Rectangle {
        visible: !!(inspector.node && inspector.node.sectionOrder && inspector.node.sectionOrder.length > 0)
        width: parent.width; height: 1
        color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.12)
      }

      Repeater {
        model: {
          if (!inspector.node || !inspector.node.sectionOrder) return []
          var out = []
          for (var i = 0; i < inspector.node.sectionOrder.length; i++) {
            var key = inspector.node.sectionOrder[i]
            out.push({ label: inspector.titleCase(key), text: inspector.node.sections[key] })
          }
          return out
        }
        delegate: Column {
          required property var modelData
          width: body.width
          spacing: 4
          Text {
            text: modelData.label
            color: Color.accent
            font.family: Style.font.family
            font.pixelSize: 12
            font.bold: true
          }
          Text {
            width: body.width
            text: modelData.text
            textFormat: Text.MarkdownText
            color: Color.foreground
            font.family: Style.font.family
            font.pixelSize: 12
            wrapMode: Text.Wrap
          }
        }
      }

      Rectangle {
        visible: !!(inspector.node && inspector.outgoing(inspector.node.id).length > 0)
        width: parent.width; height: 1
        color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.12)
      }

      Text {
        visible: !!(inspector.node && inspector.outgoing(inspector.node.id).length > 0)
        text: "Routes"
        color: Color.accent
        font.family: Style.font.family
        font.pixelSize: 12
        font.bold: true
      }

      Repeater {
        model: inspector.node ? inspector.outgoing(inspector.node.id) : []
        delegate: Rectangle {
          required property var modelData
          width: body.width
          height: routeRow.implicitHeight + 10
          radius: 6
          color: routeMa.containsMouse ? Color.menu.selectedBackground : "transparent"
          Row {
            id: routeRow
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.margins: 6
            spacing: 6
            Text {
              text: "\u2192"
              color: Color.accent
              font.pixelSize: 12
            }
            Text {
              text: modelData.to
              color: Color.foreground
              font.family: Style.font.family
              font.pixelSize: 12
              font.bold: true
            }
            Text {
              visible: !!(modelData.when && modelData.when.length > 0)
              text: "when " + modelData.when
              color: Color.muted
              font.family: Style.font.family
              font.pixelSize: 11
            }
          }
          MouseArea {
            id: routeMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: inspector.goTo(modelData.to)
          }
        }
      }

      Text {
        visible: !!(inspector.node && (!inspector.node.sectionOrder || inspector.node.sectionOrder.length === 0))
        text: "No further attributes."
        color: Color.muted
        font.family: Style.font.family
        font.pixelSize: 11
      }
    }
  }
}
