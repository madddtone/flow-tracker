import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Controls
import qs.Commons
import "FlowModel.js" as FM

Item {
  id: root

  property var shell: null
  property var manifest: null
  property string omarchyPath: Quickshell.env("OMARCHY_PATH")

  property bool opened: false
  property string stateHome: Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")
  property string activePath: Quickshell.env("FLOWC_ACTIVE") || (stateHome + "/flow-tracker/active.json")
  property string flowJsonPath: Quickshell.env("FLOWC_JSON") || ""
  property string repoRoot: ""
  property string sourceHash: ""
  property string loadError: ""
  property string compileError: ""
  property bool activeMissing: false

  property var nodesModel: []
  property var edgesModel: []
  property var byId: ({})
  property var bounds: ({ minX: 0, minY: 0, width: 800, height: 600 })
  property string flowName: ""

  // Central project store.
  property string dataHome: Quickshell.env("XDG_DATA_HOME") || (Quickshell.env("HOME") + "/.local/share")
  property string indexPath: dataHome + "/flow-tracker/index.json"
  property string flowcBin: Quickshell.env("FLOWC_BIN") || (Quickshell.env("HOME") + "/.local/bin/flowc")
  property string projectName: ""
  property string activeProjectId: ""
  property var projects: []
  property bool projectsOpen: false
  property int projectsIndex: 0

  // Subflow navigation: rootJsonPath is the active project's document;
  // flowJsonPath is whatever is currently rendered (root or a subflow).
  property string rootJsonPath: ""
  property var navStack: []      // ancestors: [{path, title}], root first
  property string viewTitle: ""  // title of the currently rendered document
  property var breadcrumbs: []

  onNavStackChanged: root.rebuildBreadcrumbs()
  onViewTitleChanged: root.rebuildBreadcrumbs()

  function rebuildBreadcrumbs() {
    var out = []
    for (var i = 0; i < root.navStack.length; i++) out.push(root.navStack[i].title || "flow")
    if (root.navStack.length > 0) out.push(root.viewTitle || root.flowName)
    root.breadcrumbs = out
  }

  property string selectedId: ""
  property string mode: "successors"   // successors | downstream
  property var hlNodes: ({})
  property var hlEdges: ({})
  property var upNodes: ({})

  property real zoom: 1.0
  property real panX: 40
  property real panY: 40
  // Manual node positions (id -> {x,y}), applied on top of the compiled layout.
  property var posOverrides: ({})

  property bool searchOpen: false
  property string searchText: ""
  property var searchResults: []
  property int searchIndex: 0

  property int inspectorWidth: 380
  readonly property bool hasSelection: selectedId !== ""
  readonly property int usableWidth: hasSelection ? viewport.width - inspectorWidth : viewport.width

  // ---------------------------------------------------------------- lifecycle

  function open(payloadJson) {
    root.opened = true
    var p = FM.parseJSON(payloadJson || "")
    if (p && typeof p === "object") {
      if (p.path) {
        root.rootJsonPath = String(p.path)
        root.navStack = []
        root.viewTitle = ""
        root.resetGraph()
        root.flowJsonPath = root.rootJsonPath
        flowView.path = root.flowJsonPath
      }
      if (p.active) root.activePath = String(p.active)
    }
    activeView.reload()
    if (root.flowJsonPath.length > 0) flowView.reload()
    Qt.callLater(function() {
      keyCatcher.forceActiveFocus()
      if (root.nodesModel.length > 0 && p && p.node) root.jumpTo(String(p.node))
      else if (root.nodesModel.length > 0) root.fit()
    })
  }

  function close(arg) {
    root.opened = false
  }

  function toggle() {
    if (root.opened) root.close(null)
    else root.open("{}")
  }

  function dismiss() {
    root.opened = false
    if (root.shell && typeof root.shell.hide === "function")
      root.shell.hide((root.manifest && root.manifest.id) || "io.github.madddtone.flow-tracker")
  }

  // ---------------------------------------------------------------- data load

  // Drop the rendered graph. Called when the active flow disappears or changes,
  // so a stale canvas never lingers after the store is cleaned or a project
  // is switched.
  function resetGraph() {
    root.nodesModel = []
    root.edgesModel = []
    root.byId = ({})
    root.bounds = ({ minX: 0, minY: 0, width: 800, height: 600 })
    root.flowName = ""
    root.selectedId = ""
    root.sourceHash = ""
    root.posOverrides = ({})
    root.hlNodes = ({})
    root.hlEdges = ({})
    root.upNodes = ({})
  }

  // ---------------------------------------------------------- node positions

  function nodePos(node) {
    var o = root.posOverrides[node.id]
    return o ? o : { x: node.rect.x, y: node.rect.y }
  }

  function effRect(id) {
    var n = root.byId[id]
    if (!n) return null
    var o = root.posOverrides[id]
    return { x: o ? o.x : n.rect.x, y: o ? o.y : n.rect.y, w: n.rect.w, h: n.rect.h }
  }

  function dragNode(id, dxScene, dyScene) {
    var n = root.byId[id]
    if (!n) return
    var dx = dxScene / root.zoom
    var dy = dyScene / root.zoom
    var o = root.posOverrides[id]
    var x = (o ? o.x : n.rect.x) + dx
    var y = (o ? o.y : n.rect.y) + dy
    var m = {}
    for (var k in root.posOverrides) m[k] = root.posOverrides[k]
    m[id] = { x: x, y: y }
    root.posOverrides = m
  }

  function effBounds() {
    var minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity
    for (var i = 0; i < root.nodesModel.length; i++) {
      var r = root.effRect(root.nodesModel[i].id)
      if (!r) continue
      minX = Math.min(minX, r.x)
      minY = Math.min(minY, r.y)
      maxX = Math.max(maxX, r.x + r.w)
      maxY = Math.max(maxY, r.y + r.h)
    }
    if (!isFinite(minX)) return root.bounds
    return { minX: minX, minY: minY, maxX: maxX, maxY: maxY, width: maxX - minX, height: maxY - minY }
  }

  function resetPositions() {
    root.posOverrides = ({})
    root.fit()
  }

  function clearActiveFlow() {
    resetGraph()
    root.flowJsonPath = ""
    root.rootJsonPath = ""
    root.navStack = []
    root.viewTitle = ""
    flowView.path = ""
    root.projectName = ""
    root.activeProjectId = ""
    root.repoRoot = ""
    root.compileError = ""
  }

  function applyActive(text) {
    var a = FM.parseJSON(text)
    if (!a || !a.jsonFile) {
      root.activeMissing = true
      root.clearActiveFlow()
      root.loadError = "No active project. Run `flowc new` then `flowc open`."
      return false
    }
    root.activeMissing = false
    root.loadError = ""
    root.repoRoot = a.repoRoot || ""
    root.projectName = a.name || ""
    root.activeProjectId = a.projectId || ""
    root.compileError = a.error ? String(a.error) : ""
    if (a.jsonFile !== root.rootJsonPath) {
      // New project: clear the old graph and any subflow navigation.
      resetGraph()
      root.rootJsonPath = a.jsonFile
      root.navStack = []
      root.viewTitle = a.name || ""
      root.flowJsonPath = a.jsonFile
      flowView.path = a.jsonFile
    }
    return true
  }

  // ------------------------------------------------------------ subflows

  function enterSubflow(id) {
    var n = root.byId[id]
    if (!n || !n.subflowJson) return
    var stack = root.navStack.slice()
    stack.push({ path: root.flowJsonPath, title: root.viewTitle.length > 0 ? root.viewTitle : root.projectName })
    root.navStack = stack
    root.viewTitle = n.subflowName || n.title || n.id
    root.resetGraph()
    root.flowJsonPath = n.subflowJson
    flowView.path = n.subflowJson
  }

  function goBack() {
    if (root.navStack.length === 0) return false
    var stack = root.navStack.slice()
    var e = stack.pop()
    root.navStack = stack
    root.viewTitle = e.title
    root.resetGraph()
    root.flowJsonPath = e.path
    flowView.path = e.path
    return true
  }

  function goToCrumb(depth) {
    if (depth >= root.navStack.length) return
    var stack = root.navStack.slice()
    while (stack.length > depth) {
      var e = stack.pop()
      root.viewTitle = e.title
      root.flowJsonPath = e.path
    }
    root.navStack = stack
    root.resetGraph()
    flowView.path = root.flowJsonPath
  }

  function loadFlow(text) {
    var doc = FM.parseJSON(text)
    if (!doc || !doc.nodes) { root.loadError = "flow.json is not valid"; return }
    var h = doc.meta && doc.meta.sourceHash ? doc.meta.sourceHash : ""
    if (h !== "" && h === root.sourceHash) return
    root.sourceHash = h
    root.loadError = ""
    var g = FM.buildGraph(doc)
    root.byId = g.byId
    root.bounds = g.bounds
    root.flowName = doc.flow || ""
    root.edgesModel = g.edges
    root.nodesModel = g.nodes
    if (root.selectedId && !g.byId[root.selectedId]) root.selectedId = ""
    root.updateHighlight()
    root.fit()
  }

  // ---------------------------------------------------------------- projects

  function loadIndex(text) {
    var idx = FM.parseJSON(text)
    root.projects = (idx && idx.projects) ? idx.projects : []
    for (var i = 0; i < root.projects.length; i++) {
      if (root.projects[i].id === root.activeProjectId) { root.projectsIndex = i; break }
    }
  }

  function openProjects() {
    root.projectsOpen = true
    indexView.reload()
  }

  function closeProjects() { root.projectsOpen = false }

  function projectMove(d) {
    if (root.projects.length === 0) return
    root.projectsIndex = (root.projectsIndex + d + root.projects.length) % root.projects.length
  }

  function acceptProject() {
    if (root.projectsIndex < 0 || root.projectsIndex >= root.projects.length) return
    var p = root.projects[root.projectsIndex]
    root.closeProjects()
    if (p.id === root.activeProjectId) return
    // Persist the switch through flowc, then let the active.json watcher reload.
    useProc.command = [root.flowcBin, "use", p.id]
    useProc.running = true
  }

  function projectSubtitle(p) {
    var bits = []
    if (p.nodes !== undefined) bits.push(p.nodes + " nodes")
    if (p.repo && p.repo.length > 0) bits.push(p.repo)
    return bits.join(" · ")
  }

  // ------------------------------------------------------------- highlight

  function setMap(obj) {
    var m = ({})
    for (var k in obj) m[k] = true
    return m
  }

  function updateHighlight() {
    if (!root.selectedId) {
      root.hlNodes = ({}); root.hlEdges = ({}); root.upNodes = ({})
      return
    }
    var succ
    if (root.mode === "downstream") {
      succ = FM.downstream(root.edgesModel, root.selectedId)
    } else {
      var es = FM.successors(root.edgesModel, root.selectedId)
      var nset = ({}), eset = ({})
      for (var i = 0; i < es.length; i++) { eset[es[i].id] = true; nset[es[i].to] = true }
      succ = { nodes: nset, edges: eset }
    }
    var anc = FM.ancestors(root.edgesModel, root.selectedId)
    root.hlNodes = succ.nodes
    root.hlEdges = succ.edges
    root.upNodes = anc.nodes
  }

  function nodeLevel(id) {
    if (id === root.selectedId) return "selected"
    if (root.upNodes[id]) return "ancestor"
    if (root.hlNodes[id]) return root.mode === "downstream" ? "downstream" : "successor"
    return "normal"
  }

  function edgeLevel(e) {
    if (!root.selectedId) return "normal"
    if (root.hlEdges[e.id]) return e.from === root.selectedId ? "selected" : (root.mode === "downstream" ? "downstream" : "successor")
    if (root.upNodes[e.from] && (e.to === root.selectedId || root.upNodes[e.to])) return "ancestor"
    return "dim"
  }

  function isDimNode(id) {
    if (!root.selectedId) return false
    if (id === root.selectedId || root.hlNodes[id] || root.upNodes[id]) return false
    return true
  }

  // ------------------------------------------------------------- selection

  function selectNode(id) {
    root.selectedId = id
    root.updateHighlight()
  }

  function clearSelection() {
    root.selectedId = ""
    root.updateHighlight()
  }

  function jumpTo(id) {
    if (!root.byId[id]) return
    root.selectNode(id)
    root.centerOn(id)
  }

  function toggleMode() {
    root.mode = root.mode === "successors" ? "downstream" : "successors"
    root.updateHighlight()
  }

  function stepTo(direction) {
    // direction: +1 successor, -1 predecessor
    var list = direction > 0
      ? FM.successors(root.edgesModel, root.selectedId)
      : FM.predecessors(root.edgesModel, root.selectedId)
    if (list.length === 0) return
    var next = direction > 0 ? list[0].to : list[0].from
    root.jumpTo(next)
  }

  // ---------------------------------------------------------------- viewport

  function clamp(v, lo, hi) { return Math.max(lo, Math.min(hi, v)) }

  function zoomAt(factor, cx, cy) {
    var old = root.zoom
    var next = root.clamp(old * factor, 0.12, 4.0)
    if (next === old) return
    var wx = (cx - root.panX) / old
    var wy = (cy - root.panY) / old
    root.zoom = next
    root.panX = cx - wx * next
    root.panY = cy - wy * next
  }

  function fit() {
    var b = root.effBounds()
    var vw = root.usableWidth
    var vh = viewport.height
    if (vw <= 0 || vh <= 0 || b.width <= 0 || b.height <= 0) return
    var pad = 90
    var z = Math.min((vw - 2 * pad) / b.width, (vh - 2 * pad) / b.height)
    z = root.clamp(z, 0.15, 1.35)
    root.zoom = z
    root.panX = (vw - b.width * z) / 2 - b.minX * z
    root.panY = (vh - b.height * z) / 2 - b.minY * z
  }

  function resetView() {
    var b = root.effBounds()
    root.zoom = 1.0
    root.panX = 40 - b.minX
    root.panY = 40 - b.minY
  }

  function centerOn(id) {
    var n = root.byId[id]
    if (!n) return
    var cx = n.rect.x + n.rect.w / 2
    var cy = n.rect.y + n.rect.h / 2
    var vw = root.usableWidth
    root.panX = vw / 2 - cx * root.zoom
    root.panY = viewport.height / 2 - cy * root.zoom
  }

  // ----------------------------------------------------------------- search

  function openSearch() {
    root.searchOpen = true
    root.searchText = ""
    root.searchResults = []
    root.searchIndex = 0
    Qt.callLater(function() { searchField.forceActiveFocus() })
  }

  function closeSearch() {
    root.searchOpen = false
  }

  function runSearch(t) {
    root.searchText = t
    root.searchResults = FM.searchNodes(root.nodesModel, t)
    if (root.searchIndex >= root.searchResults.length) root.searchIndex = 0
  }

  function searchMove(d) {
    if (root.searchResults.length === 0) return
    root.searchIndex = (root.searchIndex + d + root.searchResults.length) % root.searchResults.length
  }

  function acceptSearch() {
    if (root.searchResults.length > 0) root.jumpTo(root.searchResults[root.searchIndex].id)
    root.closeSearch()
  }

  // ------------------------------------------------------------------ models

  FileView {
    id: activeView
    path: root.activePath
    watchChanges: true
    onLoaded: root.applyActive(text())
    onLoadFailed: {
      root.activeMissing = true
      root.clearActiveFlow()
      root.loadError = "No active project. Run `flowc new` then `flowc open`."
    }
    onFileChanged: reload()
  }

  FileView {
    id: flowView
    path: root.flowJsonPath
    watchChanges: true
    onLoaded: root.loadFlow(text())
    onLoadFailed: root.loadError = root.flowJsonPath.length > 0
      ? ("Cannot read " + root.flowJsonPath) : root.loadError
    onFileChanged: reload()
  }

  FileView {
    id: indexView
    path: root.indexPath
    watchChanges: true
    onLoaded: root.loadIndex(text())
    onFileChanged: reload()
  }

  // Switching projects runs `flowc use <id>`, which rewrites active.json; the
  // active-view watcher then swaps the canvas over.
  Process {
    id: useProc
    running: false
    onExited: function(exitCode, exitStatus) {
      activeView.reload()
      indexView.reload()
    }
  }

  // FileView can miss atomic-rename writes; poll while open.
  Timer {
    interval: 1500
    repeat: true
    running: root.opened
    onTriggered: {
      activeView.reload()
      if (root.flowJsonPath.length > 0) flowView.reload()
    }
  }

  // ----------------------------------------------------------------- window

  PanelWindow {
    id: panel
    visible: root.opened
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "flow-tracker"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore

    Rectangle { anchors.fill: parent; color: Color.background }

    Item {
      id: keyCatcher
      anchors.fill: parent
      focus: true
      Keys.priority: Keys.BeforeItem
      Keys.onPressed: function(event) {
        if (root.searchOpen) {
          if (event.key === Qt.Key_Escape) { root.closeSearch(); event.accepted = true }
          else if (event.key === Qt.Key_Down) { root.searchMove(1); event.accepted = true }
          else if (event.key === Qt.Key_Up) { root.searchMove(-1); event.accepted = true }
          else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { root.acceptSearch(); event.accepted = true }
          return
        }
        if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_F) {
          root.openSearch(); event.accepted = true
          return
        }
        if (root.projectsOpen) {
          if (event.key === Qt.Key_Escape) { root.closeProjects(); event.accepted = true }
          else if (event.key === Qt.Key_Down) { root.projectMove(1); event.accepted = true }
          else if (event.key === Qt.Key_Up) { root.projectMove(-1); event.accepted = true }
          else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { root.acceptProject(); event.accepted = true }
          return
        }
        switch (event.key) {
        case Qt.Key_Escape:
          if (root.hasSelection) root.clearSelection()
          else if (root.navStack.length > 0) root.goBack()
          else root.dismiss()
          event.accepted = true
          break
        case Qt.Key_Backspace:
          if (root.goBack()) event.accepted = true
          break
        case Qt.Key_Return:
        case Qt.Key_Enter:
          if (root.hasSelection && root.byId[root.selectedId] && root.byId[root.selectedId].subflowJson) {
            root.enterSubflow(root.selectedId)
            event.accepted = true
          }
          break
        case Qt.Key_Q:
          root.dismiss(); event.accepted = true; break
        case Qt.Key_P:
          root.openProjects(); event.accepted = true; break
        case Qt.Key_Slash:
          root.openSearch(); event.accepted = true; break
        case Qt.Key_D:
          root.toggleMode(); event.accepted = true; break
        case Qt.Key_F:
          root.fit(); event.accepted = true; break
        case Qt.Key_0:
          root.resetView(); event.accepted = true; break
        case Qt.Key_R:
          root.resetPositions(); event.accepted = true; break
        case Qt.Key_Plus:
        case Qt.Key_Equal:
          root.zoomAt(1.15, root.usableWidth / 2, viewport.height / 2); event.accepted = true; break
        case Qt.Key_Minus:
          root.zoomAt(1 / 1.15, root.usableWidth / 2, viewport.height / 2); event.accepted = true; break
        case Qt.Key_Right:
        case Qt.Key_Down:
          if (root.hasSelection) { root.stepTo(1); event.accepted = true }
          break
        case Qt.Key_Left:
        case Qt.Key_Up:
          if (root.hasSelection) { root.stepTo(-1); event.accepted = true }
          break
        }
      }
    }

    // ---------------------------------------------------------- canvas

    Item {
      id: viewport
      anchors.fill: parent
      clip: true

      MouseArea {
        id: panArea
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        property real lastX: 0
        property real lastY: 0
        property bool dragging: false
        property bool moved: false
        onPressed: function(mouse) {
          lastX = mouse.x; lastY = mouse.y; dragging = true; moved = false
        }
        onPositionChanged: function(mouse) {
          if (!dragging) return
          var dx = mouse.x - lastX
          var dy = mouse.y - lastY
          if (Math.abs(dx) + Math.abs(dy) > 2) moved = true
          root.panX += dx
          root.panY += dy
          lastX = mouse.x; lastY = mouse.y
        }
        onReleased: dragging = false
        onClicked: if (!moved) root.clearSelection()
        onWheel: function(wheel) {
          var f = wheel.angleDelta.y > 0 ? 1.12 : 1 / 1.12
          root.zoomAt(f, wheel.x, wheel.y)
        }
      }

      Item {
        id: world
        x: root.panX
        y: root.panY
        transformOrigin: Item.TopLeft
        scale: root.zoom

        Repeater {
          model: root.edgesModel
          delegate: EdgeItem {
            required property var modelData
            edge: modelData
            sourceRect: root.effRect(modelData.from)
            targetRect: root.effRect(modelData.to)
            worldW: 40000
            worldH: 40000
            level: root.edgeLevel(modelData)
            visible: sourceRect !== undefined && targetRect !== undefined
          }
        }

        Repeater {
          model: root.nodesModel
          delegate: NodeItem {
            required property var modelData
            node: modelData
            x: root.nodePos(modelData).x
            y: root.nodePos(modelData).y
            isSelected: modelData.id === root.selectedId
            isSuccessor: root.nodeLevel(modelData.id) === "successor"
            isDownstream: root.nodeLevel(modelData.id) === "downstream"
            isAncestor: root.nodeLevel(modelData.id) === "ancestor"
            isDim: root.isDimNode(modelData.id)
            onActivated: function(id) { root.selectNode(id) }
            onOpened: function(id) { root.enterSubflow(id) }
            onDragged: function(id, dx, dy) { root.dragNode(id, dx, dy) }
          }
        }
      }
    }

    // ---------------------------------------------------------- header

    Rectangle {
      id: header
      anchors { top: parent.top; left: parent.left; right: parent.right }
      height: 52
      color: Qt.rgba(Color.background.r, Color.background.g, Color.background.b, 0.92)

      Row {
        anchors.fill: parent
        anchors.leftMargin: 18
        anchors.rightMargin: 18
        spacing: 12

        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: "\u22b3"
          color: Color.accent
          font.pixelSize: 22
        }
        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: root.projectName.length > 0
            ? root.projectName
            : (root.flowName.length > 0 ? root.flowName : "Flow Tracker")
          color: Color.foreground
          font.family: Style.font.family
          font.pixelSize: 16
          font.bold: true
        }
        Text {
          anchors.verticalCenter: parent.verticalCenter
          visible: root.nodesModel.length > 0
          text: root.nodesModel.length + " nodes · " + root.edgesModel.length + " edges"
          color: Color.muted
          font.family: Style.font.family
          font.pixelSize: 11
        }

        Rectangle {
          anchors.verticalCenter: parent.verticalCenter
          radius: 5
          color: projMa.containsMouse ? Color.menu.selectedBackground
            : Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.16)
          implicitWidth: projText.implicitWidth + 16
          implicitHeight: 22
          Text {
            id: projText
            anchors.centerIn: parent
            text: "Projects (" + root.projects.length + ")  [p]"
            color: Color.accent
            font.family: Style.font.family
            font.pixelSize: 10
            font.bold: true
          }
          MouseArea {
            id: projMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.openProjects()
          }
        }

        Rectangle {
          anchors.verticalCenter: parent.verticalCenter
          radius: 5
          color: findMa.containsMouse ? Color.menu.selectedBackground
            : Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.16)
          implicitWidth: findText.implicitWidth + 16
          implicitHeight: 22
          Text {
            id: findText
            anchors.centerIn: parent
            text: "Find node  [ / ]"
            color: Color.accent
            font.family: Style.font.family
            font.pixelSize: 10
            font.bold: true
          }
          MouseArea {
            id: findMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.openSearch()
          }
        }

        Text {
          anchors.verticalCenter: parent.verticalCenter
          visible: root.repoRoot.length > 0
          text: root.repoRoot
          color: Color.muted
          font.family: Style.font.family
          font.pixelSize: 11
          elide: Text.ElideMiddle
          width: Math.min(implicitWidth, 320)
        }

        Item { width: 1; height: 1 }

        Rectangle {
          anchors.verticalCenter: parent.verticalCenter
          visible: root.hasSelection
          radius: 5
          color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.16)
          implicitWidth: modeText.implicitWidth + 16
          implicitHeight: 22
          Text {
            id: modeText
            anchors.centerIn: parent
            text: root.mode === "downstream" ? "downstream (d)" : "next steps (d)"
            color: Color.accent
            font.family: Style.font.family
            font.pixelSize: 10
            font.bold: true
          }
        }
      }
    }

    // ---------------------------------------------------------- breadcrumb

    Item {
      id: navBar
      anchors { top: header.bottom; left: parent.left; right: parent.right }
      height: root.navStack.length > 0 ? 28 : 0
      clip: true

      Rectangle {
        anchors.fill: parent
        color: Qt.rgba(Color.background.r, Color.background.g, Color.background.b, 0.9)
        border.width: 1
        border.color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)
      }

      Row {
        anchors.fill: parent
        anchors.leftMargin: 18
        anchors.rightMargin: 18
        spacing: 4

        Repeater {
          model: root.breadcrumbs
          delegate: Item {
            required property var modelData
            required property int index
            width: crumbText.implicitWidth + 18
            height: navBar.height

            Text {
              id: crumbText
              anchors.verticalCenter: parent.verticalCenter
              text: modelData
              color: index === root.navStack.length ? Color.foreground : Color.accent
              font.family: Style.font.family
              font.pixelSize: 11
              font.bold: index === root.navStack.length
            }
            Text {
              visible: index < root.navStack.length
              anchors.left: crumbText.right
              anchors.leftMargin: 4
              anchors.verticalCenter: parent.verticalCenter
              text: "›"
              color: Color.muted
              font.pixelSize: 11
            }
            MouseArea {
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: index < root.navStack.length ? Qt.PointingHandCursor : Qt.ArrowCursor
              onClicked: root.goToCrumb(index)
            }
          }
        }
      }
    }

    // ---------------------------------------------------------- error banner

    Rectangle {
      anchors { top: navBar.bottom; left: parent.left; right: parent.right }
      height: Math.max(errText.implicitHeight + 14, 0)
      visible: root.compileError.length > 0 || root.loadError.length > 0
      color: Qt.rgba(Color.urgent.r, Color.urgent.g, Color.urgent.b, 0.22)
      Text {
        id: errText
        anchors.fill: parent
        anchors.margins: 8
        anchors.leftMargin: 18
        text: root.compileError.length > 0 ? ("compile error: " + root.compileError) : root.loadError
        color: Color.foreground
        font.family: Style.font.family
        font.pixelSize: 12
        wrapMode: Text.Wrap
        verticalAlignment: Text.AlignVCenter
      }
    }

    // ---------------------------------------------------------- empty state

    Column {
      anchors.centerIn: parent
      spacing: 10
      visible: root.nodesModel.length === 0 && (root.activeMissing || root.loadError.length > 0)
      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: "\u2b1a"
        color: Color.muted
        font.pixelSize: 40
      }
      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: root.activeMissing ? "No active project" : "Nothing to show"
        color: Color.foreground
        font.family: Style.font.family
        font.pixelSize: 16
        font.bold: true
      }
      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: "Create one with:\n  flowc new \"My Project\"\n  flowc open my-project"
        color: Color.muted
        font.family: Style.font.family
        font.pixelSize: 12
        horizontalAlignment: Text.AlignHCenter
      }
    }

    // ---------------------------------------------------------- inspector

    Inspector {
      id: inspector
      visible: root.hasSelection
      width: root.inspectorWidth
      anchors { top: navBar.bottom; right: parent.right; bottom: parent.bottom }
      node: root.byId[root.selectedId]
      edges: root.edgesModel
      byId: root.byId
      onCloseRequested: root.clearSelection()
      onGoTo: function(id) { root.jumpTo(id) }
      onOpenSubflow: function(id) { root.enterSubflow(id) }
    }

    // ---------------------------------------------------------- search

    Rectangle {
      visible: root.searchOpen
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.top: header.bottom
      anchors.topMargin: 16
      width: Math.min(560, panel.width - 80)
      height: searchColumn.implicitHeight + 20
      radius: 10
      color: Color.menu.background
      border.width: 1
      border.color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.5)

      Column {
        id: searchColumn
        anchors.fill: parent
        anchors.margins: 10
        spacing: 6
        TextField {
          id: searchField
          width: parent.width
          placeholderText: "Find a node by id, title, actor or tag…"
          onTextChanged: root.runSearch(text)
          onAccepted: root.acceptSearch()
          Keys.onEscapePressed: root.closeSearch()
        }
        ListView {
          id: resultsList
          width: searchColumn.width
          height: root.searchResults.length > 0 ? Math.min(root.searchResults.length * 30, 300) : 0
          clip: true
          model: root.searchResults
          boundsBehavior: Flickable.StopAtBounds
          delegate: Rectangle {
            required property var modelData
            required property int index
            width: resultsList.width
            height: 30
            radius: 6
            color: (index === root.searchIndex || rowMa.containsMouse)
              ? Color.menu.selectedBackground : "transparent"
            Row {
              anchors.fill: parent
              anchors.leftMargin: 8
              spacing: 8
              Text { anchors.verticalCenter: parent.verticalCenter; text: modelData.id; color: Color.foreground; font.family: Style.font.family; font.pixelSize: 12; font.bold: true }
              Text { anchors.verticalCenter: parent.verticalCenter; text: modelData.title || ""; color: Color.muted; font.family: Style.font.family; font.pixelSize: 11 }
            }
            MouseArea {
              id: rowMa
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                root.searchIndex = index
                root.jumpTo(modelData.id)
                root.closeSearch()
              }
            }
          }
        }
        Connections {
          target: root
          function onSearchIndexChanged() {
            if (root.searchOpen) resultsList.positionViewAtIndex(root.searchIndex, ListView.Contain)
          }
          function onSearchResultsChanged() {
            if (root.searchOpen) resultsList.positionViewAtIndex(root.searchIndex, ListView.Contain)
          }
        }
      }
    }

    // ---------------------------------------------------------- projects

    Rectangle {
      visible: root.projectsOpen
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.top: header.bottom
      anchors.topMargin: 16
      width: Math.min(620, panel.width - 80)
      height: Math.min(560, projectCol.implicitHeight + 24)
      radius: 10
      color: Color.menu.background
      border.width: 1
      border.color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.5)

      Column {
        id: projectCol
        anchors { left: parent.left; right: parent.right; top: parent.top }
        anchors.margins: 12
        spacing: 6

        Text {
          text: "Projects"
          color: Color.foreground
          font.family: Style.font.family
          font.pixelSize: 14
          font.bold: true
        }
        Text {
          visible: root.projects.length === 0
          text: "No projects yet. Create one with:\n  flowc new \"My Project\""
          color: Color.muted
          font.family: Style.font.family
          font.pixelSize: 12
        }

        Repeater {
          model: root.projects
          delegate: Rectangle {
            required property var modelData
            required property int index
            width: projectCol.width
            height: 46
            radius: 7
            color: (index === root.projectsIndex || rowMa.containsMouse)
              ? Color.menu.selectedBackground : "transparent"
            border.width: modelData.id === root.activeProjectId ? 1 : 0
            border.color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.6)

            Column {
              anchors.left: parent.left
              anchors.leftMargin: 10
              anchors.right: activeTag.left
              anchors.rightMargin: 10
              anchors.verticalCenter: parent.verticalCenter
              spacing: 2
              Text {
                width: parent.width
                text: modelData.name || modelData.id
                color: Color.foreground
                font.family: Style.font.family
                font.pixelSize: 13
                font.bold: true
                elide: Text.ElideRight
              }
              Text {
                width: parent.width
                text: root.projectSubtitle(modelData)
                color: Color.muted
                font.family: Style.font.family
                font.pixelSize: 10
                elide: Text.ElideRight
              }
            }
            Text {
              id: activeTag
              anchors.right: parent.right
              anchors.rightMargin: 12
              anchors.verticalCenter: parent.verticalCenter
              visible: modelData.id === root.activeProjectId
              text: "active"
              color: Color.accent
              font.family: Style.font.family
              font.pixelSize: 10
              font.bold: true
            }

            MouseArea {
              id: rowMa
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                root.projectsIndex = index
                root.acceptProject()
              }
            }
          }
        }

        Text {
          visible: root.projects.length > 0
          text: "↑/↓ move · enter open · esc close"
          color: Color.muted
          font.family: Style.font.family
          font.pixelSize: 10
        }
      }
    }

    // ---------------------------------------------------------- footer hints

    Rectangle {
      anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
      height: 30
      color: Qt.rgba(Color.background.r, Color.background.g, Color.background.b, 0.85)
      Text {
        anchors.centerIn: parent
        text: "click: trace · drag node: move · drag bg: pan · dbl-click subflow: open · d: next/full · /: find · p: projects · r: reset layout · f: fit · q: close"
        color: Color.muted
        font.family: Style.font.family
        font.pixelSize: 10
      }
    }
  }
}
