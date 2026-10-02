import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "omarchy.workspaces"

  function workspaceById(id) {
    var values = Hyprland.workspaces.values
    for (var i = 0; i < values.length; i++) {
      if (values[i].id === id) return values[i]
    }

    return null
  }

  function workspaceIds() {
    var ids = [1, 2, 3, 4, 5]
    var values = Hyprland.workspaces.values

    for (var i = 0; i < values.length; i++) {
      var id = values[i].id
      if (id > 0 && id <= 10 && ids.indexOf(id) === -1) ids.push(id)
    }

    ids.sort(function(left, right) { return left - right })
    return ids
  }

  function focusWorkspace(id) {
    if (!root.bar) return
    root.bar.run("hyprctl dispatch " + Util.shellQuote("hl.dsp.focus({ workspace = \"" + id + "\" })"))
  }

  // ---- Custom workspace names, persisted to disk. Renaming a workspace
  //      number via right-click sticks until it's renamed again or reset.
  property string namesPath: Quickshell.env("HOME") + "/.local/state/omarchy/settings/workspace-names.json"
  property var names: ({})

  function nameFor(id) {
    var value = root.names[String(id)]
    return value ? value : ""
  }

  function setName(id, name) {
    var updated = Object.assign({}, root.names)
    if (name === "") delete updated[String(id)]
    else updated[String(id)] = name
    root.names = updated
    namesFile.setText(JSON.stringify(root.names, null, 2) + "\n")
  }

  function parseNames(text) {
    try {
      var parsed = JSON.parse(text)
      return (parsed && typeof parsed === "object") ? parsed : {}
    } catch (e) {
      return {}
    }
  }

  FileView {
    id: namesFile
    path: root.namesPath
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onLoaded: root.names = root.parseNames(text())
    onLoadFailed: root.names = {}
    onFileChanged: reload()
  }

  // ---- Number prefix. Both values live inline on this widget's shell.json
  //      entry. Numbers show by default; hiddenNumbers lists the workspaces
  //      whose number was switched off from the rename popup.
  readonly property var hiddenNumbers: setting("hiddenNumbers", [])
  readonly property real numberOpacity: Number(setting("numberOpacity", 0.5))

  function numberLabel(id) {
    return id === 10 ? "0" : String(id)
  }

  function showsNumber(id) {
    return root.hiddenNumbers.indexOf(id) === -1
  }

  function setShowNumber(id, show) {
    if (root.showsNumber(id) === show) return
    var hidden = root.hiddenNumbers.filter(function(other) { return other !== id })
    if (!show) hidden.push(id)
    var entry = Object.assign({}, root.settings)
    entry.hiddenNumbers = hidden
    root.settings = entry
    if (root.bar && root.bar.shell) root.bar.shell.updateEntryInline(root.moduleName, entry)
  }

  property int renameWorkspaceId: -1
  property var renameAnchorItem: null
  property bool renamePopupOpen: false
  property bool renameShowNumber: true

  function close() { renamePopupOpen = false }

  function openRename(id, anchorItem) {
    if (root.renamePopupOpen && root.renameAnchorItem !== anchorItem) {
      root.renamePopupOpen = false
      Qt.callLater(function() { root.beginRename(id, anchorItem) })
      return
    }
    root.beginRename(id, anchorItem)
  }

  function beginRename(id, anchorItem) {
    renameWorkspaceId = id
    renameAnchorItem = anchorItem
    renameShowNumber = showsNumber(id)
    renamePopupOpen = true
    Qt.callLater(function() {
      renameField.text = root.nameFor(id)
      renameField.selectAll()
      renameField.forceActiveFocus()
    })
  }

  function commitRename() {
    root.setName(root.renameWorkspaceId, renameField.text.trim())
    root.setShowNumber(root.renameWorkspaceId, root.renameShowNumber)
    root.close()
  }

  function resetRename() {
    root.setName(root.renameWorkspaceId, "")
    root.setShowNumber(root.renameWorkspaceId, true)
    root.close()
  }

  readonly property real trailingGap: root.vertical ? 0 : Style.spaceReal(1.5)

  implicitWidth: grid.implicitWidth + trailingGap
  implicitHeight: grid.implicitHeight

  GridLayout {
    id: grid
    anchors.fill: parent
    anchors.rightMargin: root.trailingGap
    columns: root.vertical ? 1 : root.workspaceIds().length
    columnSpacing: root.vertical ? 0 : Style.space(1)
    rowSpacing: root.vertical ? Style.space(2) : 0

    Repeater {
      model: root.workspaceIds()

      Item {
        id: cell
        required property int modelData

        readonly property var workspace: root.workspaceById(modelData)
        readonly property bool occupied: workspace !== null && workspace.toplevels.values.length > 0
        readonly property bool focused: Hyprland.focusedWorkspace !== null && Hyprland.focusedWorkspace.id === modelData
        readonly property string customName: root.nameFor(modelData)
        readonly property bool numbered: root.showsNumber(modelData) && !root.vertical && customName !== ""
        readonly property color textColor: focused ? Color.accent : root.bar.barForeground

        implicitWidth: workspaceButton.implicitWidth
        implicitHeight: workspaceButton.implicitHeight

        Rectangle {
          anchors.fill: parent
          visible: cell.focused
          radius: Style.cornerRadius
          color: Style.selectedFillFor(root.bar.foreground, Color.accent)
        }

        WidgetButton {
          id: workspaceButton
          anchors.fill: parent

          bar: root.bar
          text: cell.customName !== "" ? cell.customName : root.numberLabel(cell.modelData)
          labelVisible: !cell.numbered
          tooltipText: cell.customName !== "" ? cell.customName : "Right-click to rename"
          active: cell.focused
          activeColor: Color.accent
          opacity: cell.occupied || cell.focused ? 1 : 0.5
          horizontalMargin: 6
          verticalPadding: 6
          fixedWidth: root.vertical ? root.barSize
            : cell.numbered ? numberedLabel.implicitWidth + scaledHorizontalMargin * 2
            : (cell.customName !== "" ? -1 : Style.space(20))
          fixedHeight: root.barSize
          onPressed: function(button) {
            if (button === Qt.RightButton) root.openRename(cell.modelData, workspaceButton)
            else root.focusWorkspace(cell.modelData)
          }
        }

        // "<number> <name>" label. The inner gap is tighter than the gap
        // between workspaces so the number reads as part of its name.
        Row {
          id: numberedLabel
          anchors.centerIn: parent
          visible: cell.numbered
          opacity: workspaceButton.opacity
          spacing: Style.spaceReal(3)

          Text {
            text: root.numberLabel(cell.modelData)
            opacity: root.numberOpacity
            color: cell.textColor
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.body
            renderType: Text.NativeRendering
          }
          Text {
            textFormat: Text.PlainText
            text: cell.customName
            color: cell.textColor
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.body
            renderType: Text.NativeRendering
          }
        }
      }
    }
  }

  KeyboardPanel {
    id: renamePopup
    anchorItem: root.renameAnchorItem
    bar: root.bar
    owner: root
    open: root.renamePopupOpen && root.renameAnchorItem !== null
    focusTarget: renameField
    contentWidth: renamePopup.fittedContentWidth(Style.space(220))
    contentHeight: renamePopup.fittedContentHeight(renameColumn.implicitHeight)

    Column {
      id: renameColumn
      width: parent.width
      spacing: Style.space(10)

      Text {
        text: "Rename Workspace " + (root.renameWorkspaceId === 10 ? "0" : String(root.renameWorkspaceId))
        color: root.bar.foreground
        font.family: root.bar.fontFamily
        font.pixelSize: Style.font.bodySmall
        font.bold: true
      }

      TextField {
        id: renameField
        width: parent.width
        placeholderText: "Workspace name"
        foreground: root.bar.foreground

        Keys.onPressed: function(event) {
          if (event.key === Qt.Key_Escape) {
            root.close()
            event.accepted = true
          } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.commitRename()
            event.accepted = true
          }
        }
      }

      Item {
        width: showNumbersRow.implicitWidth
        height: showNumbersRow.implicitHeight

        Row {
          id: showNumbersRow
          spacing: Style.space(8)

          Rectangle {
            width: Style.space(14)
            height: width
            anchors.verticalCenter: parent.verticalCenter
            radius: Style.cornerRadius > 0 ? 3 : 0
            color: root.renameShowNumber ? Color.accent : "transparent"
            border.width: 1
            border.color: root.renameShowNumber ? Color.accent : root.bar.foreground

            Text {
              anchors.centerIn: parent
              visible: root.renameShowNumber
              text: "✓"
              color: root.bar.background
              font.pixelSize: Style.font.bodySmall
              font.bold: true
            }
          }
          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "Show workspace number"
            color: root.bar.foreground
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.bodySmall
          }
        }

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: root.renameShowNumber = !root.renameShowNumber
        }
      }

      Row {
        anchors.right: parent.right
        spacing: Style.space(8)

        Button {
          text: "Reset"
          foreground: root.bar.foreground
          onClicked: root.resetRename()
        }
        Button {
          text: "Save"
          foreground: root.bar.foreground
          onClicked: root.commitRename()
        }
      }
    }
  }
}
