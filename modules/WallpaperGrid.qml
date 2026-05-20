import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../components"

Item {
    id: root

    // ── Public ───────────────────────────────────────────────────────────
    property var    model:      null
    property string filterText: ""
    signal applyRequested(string workshopId, string wallpaperPath)

    // ── Hidden wallpapers ─────────────────────────────────────────────────
    property var  hiddenIds:      []
    property bool _hiddenUnlocked: false
    readonly property string _hiddenPassword: "1234"   // ← change this

    // ── Filtered proxy ────────────────────────────────────────────────────
    property var filteredItems: []

    function rebuildFilter() {
        if (!model) { filteredItems = []; return }
        var ft  = filterText.toLowerCase()
        var arr = []
        for (var i = 0; i < model.count; i++) {
            var item = model.get(i)
            if (hiddenIds.indexOf(item.workshopId) !== -1) continue
            if (ft === "" ||
                item.title.toLowerCase().indexOf(ft) !== -1 ||
                item.workshopId.indexOf(ft) !== -1) {
                arr.push({
                    workshopId:    item.workshopId,
                    title:         item.title,
                    wallpaperType: item.wallpaperType,
                    previewPath:   item.previewPath,
                    folderPath:    item.folderPath
                })
            }
        }
        filteredItems = arr
    }

    onFilterTextChanged:  rebuildFilter()
    onHiddenIdsChanged:   rebuildFilter()
    onModelChanged: {
        if (model) model.countChanged.connect(rebuildFilter)
        rebuildFilter()
    }

    // ── Public functions (called by WallpaperSwitcherWindow toolbar) ──────
    function hideWallpaper(workshopId) {
        var ids = hiddenIds.slice()
        if (ids.indexOf(workshopId) === -1) ids.push(workshopId)
        hiddenIds = ids
    }

    function showHidden() {
        if (_hiddenUnlocked) {
            hiddenOverlay.visible = true
        } else {
            passwordPrompt.open()
        }
    }

    // ── Delete helpers ────────────────────────────────────────────────────
    property string _pendingDeleteId:   ""
    property string _pendingDeletePath: ""

    function requestDelete(workshopId, folderPath) {
        _pendingDeleteId   = workshopId
        _pendingDeletePath = folderPath
        deleteDialog.open()
    }

    // ── Delete process ────────────────────────────────────────────────────
    Process {
        id: deleteProc
        stdout: SplitParser { onRead: function(line) { console.log("rm:", line) } }
        stderr: SplitParser { onRead: function(line) { console.log("rm err:", line) } }
        onExited: function(code) {
            if (code !== 0) return
            var ids = root.hiddenIds.filter(function(id) { return id !== root._pendingDeleteId })
            root.hiddenIds = ids
            for (var i = 0; i < root.model.count; i++) {
                if (root.model.get(i).workshopId === root._pendingDeleteId) {
                    root.model.remove(i); break
                }
            }
            root._pendingDeleteId   = ""
            root._pendingDeletePath = ""
        }
    }

    // ── Empty state ────────────────────────────────────────────────────────
    Column {
        anchors.centerIn: parent
        spacing: 16
        visible: root.filteredItems.length === 0 && !hiddenOverlay.visible

        Text { anchors.horizontalCenter: parent.horizontalCenter
               text: "◈"; color: "#2a2f3a"; font.pixelSize: 48 }
        Text { anchors.horizontalCenter: parent.horizontalCenter
               text: root.filterText !== "" ? "No results for \"" + root.filterText + "\""
                                            : "No wallpapers found"
               color: "#3a4050"; font.pixelSize: 13; font.family: "monospace" }
        Text { anchors.horizontalCenter: parent.horizontalCenter
               text: root.filterText === "" ? "Make sure Steam Workshop wallpapers are downloaded" : ""
               color: "#2a3040"; font.pixelSize: 11; font.family: "monospace" }
    }

    // ── Main grid ──────────────────────────────────────────────────────────
    ScrollView {
        anchors.fill: parent
        anchors.margins: 20
        ScrollBar.horizontal: ScrollBar { policy: ScrollBar.AlwaysOff }
        clip: true

        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded; width: 4
            contentItem: Rectangle { radius: 2; color: "#2a6aff"; opacity: 0.7 }
            background:  Rectangle { color: "#1a1e26"; radius: 2 }
        }

        GridView {
            id: grid
            width: root.width - 40
            cellWidth: 240; cellHeight: 200
            model: root.filteredItems.length

            delegate: Item {
                width: grid.cellWidth; height: grid.cellHeight
                WallpaperCard {
                    anchors.fill: parent; anchors.margins: 8
                    workshopId:    root.filteredItems[index].workshopId
                    title:         root.filteredItems[index].title
                    wallpaperType: root.filteredItems[index].wallpaperType
                    previewPath:   root.filteredItems[index].previewPath
                    folderPath:    root.filteredItems[index].folderPath
                    onApplyRequested:  function(wid, wpath) { root.applyRequested(wid, wpath) }
                    onHideRequested:   function(wid)        { root.hideWallpaper(wid) }
                    onDeleteRequested: function(wid, fpath) { root.requestDelete(wid, fpath) }
                }
            }
        }
    }

    // ── Hidden wallpapers overlay (replaces Drawer — works in FloatingWindow) ──
    Rectangle {
        id: hiddenOverlay
        anchors.fill: parent
        visible: false
        z: 10
        color: "#0f1118"

        // Slide-in animation
        property real _progress: visible ? 1.0 : 0.0
        Behavior on _progress { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        transform: Translate { y: hiddenOverlay.height * (1.0 - hiddenOverlay._progress) }
        opacity: hiddenOverlay._progress

        Column {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            // ── Header row ────────────────────────────────────────────────
            Item {
                width: parent.width; height: 36

                Text {
                    text: "Hidden Wallpapers  (" + root.hiddenIds.length + ")"
                    color: "#7090c0"; font.pixelSize: 14; font.weight: Font.Bold
                    anchors.verticalCenter: parent.verticalCenter
                }

                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    // Lock button
                    Rectangle {
                        width: 72; height: 28; radius: 7
                        color: lockHov.containsMouse ? "#1e2535" : "#16191f"
                        border.color: "#2a3040"; border.width: 1
                        Text { anchors.centerIn: parent; text: "🔒 Lock"
                               color: "#607090"; font.pixelSize: 11 }
                        HoverHandler { id: lockHov }
                        TapHandler {
                            onTapped: {
                                root._hiddenUnlocked = false
                                hiddenOverlay.visible = false
                            }
                        }
                    }

                    // Close button
                    Rectangle {
                        width: 28; height: 28; radius: 7
                        color: closeHidHov.containsMouse ? "#2a1a1a" : "#16191f"
                        border.color: closeHidHov.containsMouse ? "#ff4444" : "#2a3040"
                        border.width: 1
                        Text { anchors.centerIn: parent; text: "✕"
                               color: closeHidHov.containsMouse ? "#ff4444" : "#607090"
                               font.pixelSize: 11 }
                        HoverHandler { id: closeHidHov }
                        TapHandler { onTapped: hiddenOverlay.visible = false }
                    }
                }
            }

            // Divider
            Rectangle { width: parent.width; height: 1; color: "#1e2535" }

            // ── Hidden grid ───────────────────────────────────────────────
            ScrollView {
                width: parent.width
                height: parent.height - 56
                clip: true
                ScrollBar.horizontal: ScrollBar { policy: ScrollBar.AlwaysOff }
                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded; width: 4
                    contentItem: Rectangle { radius: 2; color: "#2a6aff"; opacity: 0.7 }
                    background:  Rectangle { color: "#1a1e26"; radius: 2 }
                }

                GridView {
                    id: hiddenGrid
                    width: hiddenOverlay.width - 32
                    cellWidth: 240; cellHeight: 210

                    property var hiddenItems: {
                        var arr = []
                        if (!root.model) return arr
                        for (var i = 0; i < root.model.count; i++) {
                            var it = root.model.get(i)
                            if (root.hiddenIds.indexOf(it.workshopId) !== -1)
                                arr.push({
                                    workshopId:    it.workshopId,
                                    title:         it.title,
                                    wallpaperType: it.wallpaperType,
                                    previewPath:   it.previewPath,
                                    folderPath:    it.folderPath
                                })
                        }
                        return arr
                    }

                    model: hiddenItems.length

                    // Empty state for hidden grid
                    Text {
                        anchors.centerIn: parent
                        visible: hiddenGrid.count === 0
                        text: "No hidden wallpapers"
                        color: "#2a3a50"; font.pixelSize: 13; font.family: "monospace"
                    }

                    delegate: Item {
                        width: hiddenGrid.cellWidth; height: hiddenGrid.cellHeight

                        WallpaperCard {
                            anchors.fill: parent
                            anchors.margins: 8
                            anchors.bottomMargin: 36   // room for unhide button
                            workshopId:    hiddenGrid.hiddenItems[index].workshopId
                            title:         hiddenGrid.hiddenItems[index].title
                            wallpaperType: hiddenGrid.hiddenItems[index].wallpaperType
                            previewPath:   hiddenGrid.hiddenItems[index].previewPath
                            folderPath:    hiddenGrid.hiddenItems[index].folderPath
                            onApplyRequested:  function(wid, wpath) { root.applyRequested(wid, wpath) }
                            onHideRequested:   function(wid) {
                                // Hide from hidden drawer = unhide
                                root.hiddenIds = root.hiddenIds.filter(function(id) { return id !== wid })
                            }
                            onDeleteRequested: function(wid, fpath) { root.requestDelete(wid, fpath) }
                        }

                        // Unhide button
                        Rectangle {
                            anchors.bottom: parent.bottom; anchors.bottomMargin: 4
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 88; height: 26; radius: 6
                            color: unhideHov.containsMouse ? "#1a3a1a" : "#121a12"
                            border.color: unhideHov.containsMouse ? "#3a8a3a" : "#2a4a2a"
                            border.width: 1
                            Text { anchors.centerIn: parent; text: "↑ Unhide"
                                   color: "#4aaa4a"; font.pixelSize: 10; font.weight: Font.Bold }
                            HoverHandler { id: unhideHov }
                            TapHandler {
                                onTapped: {
                                    var wid = hiddenGrid.hiddenItems[index].workshopId
                                    root.hiddenIds = root.hiddenIds.filter(function(id) { return id !== wid })
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ── Delete confirmation dialog ─────────────────────────────────────────
    Dialog {
        id: deleteDialog
        anchors.centerIn: parent
        width: 320; modal: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        z: 20

        background: Rectangle {
            color: "#13161e"; radius: 12
            border.color: "#ff3333"; border.width: 1
        }

        Column {
            width: parent.width; spacing: 16; padding: 8

            Text { text: "Delete Wallpaper?"
                   color: "#ff6666"; font.pixelSize: 15; font.weight: Font.Bold
                   anchors.horizontalCenter: parent.horizontalCenter }
            Text { width: parent.width - 16
                   text: "This will permanently delete:\n" + root._pendingDeletePath
                   color: "#8090a8"; font.pixelSize: 11; font.family: "monospace"
                   wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                   anchors.horizontalCenter: parent.horizontalCenter }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter; spacing: 12

                Rectangle {
                    width: 100; height: 34; radius: 7
                    color: cancelHov.containsMouse ? "#1e2535" : "#16191f"
                    border.color: "#2a3040"; border.width: 1
                    Text { anchors.centerIn: parent; text: "Cancel"; color: "#8090a8"; font.pixelSize: 12 }
                    HoverHandler { id: cancelHov }
                    TapHandler { onTapped: deleteDialog.close() }
                }

                Rectangle {
                    width: 100; height: 34; radius: 7
                    color: confirmHov.containsMouse ? "#cc2222" : "#991a1a"
                    Text { anchors.centerIn: parent; text: "Delete"; color: "#fff"; font.pixelSize: 12; font.weight: Font.Bold }
                    HoverHandler { id: confirmHov }
                    TapHandler {
                        onTapped: {
                            deleteDialog.close()
                            if (root._pendingDeletePath !== "") {
                                deleteProc.command = ["bash", "-c",
                                    "rm -rf \"" + root._pendingDeletePath + "\""]
                                deleteProc.running = true
                            }
                        }
                    }
                }
            }
        }
    }

    // ── Password prompt ────────────────────────────────────────────────────
    Dialog {
        id: passwordPrompt
        anchors.centerIn: parent
        width: 300; modal: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        z: 20

        background: Rectangle {
            color: "#13161e"; radius: 12
            border.color: "#1e4aaa"; border.width: 1
        }

        Column {
            width: parent.width; spacing: 14; padding: 8

            Text { text: "🔒  Hidden Wallpapers"
                   color: "#a0b0d0"; font.pixelSize: 14; font.weight: Font.Bold
                   anchors.horizontalCenter: parent.horizontalCenter }
            Text { text: "Enter password to view"
                   color: "#4a5a70"; font.pixelSize: 11
                   anchors.horizontalCenter: parent.horizontalCenter }

            TextField {
                id: pwField
                width: parent.width - 16
                anchors.horizontalCenter: parent.horizontalCenter
                echoMode: TextInput.Password
                placeholderText: "Password"
                color: "#c0cce0"; font.pixelSize: 13
                background: Rectangle {
                    color: "#0d0f14"; radius: 7
                    border.color: pwField.activeFocus ? "#2a6aff" : "#1e2535"
                    border.width: 1
                }
                onAccepted: passwordPrompt.checkPassword()
            }

            Text { id: pwError; text: "Incorrect password"
                   color: "#ff4444"; font.pixelSize: 11; visible: false
                   anchors.horizontalCenter: parent.horizontalCenter }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter; spacing: 10

                Rectangle {
                    width: 90; height: 32; radius: 7
                    color: pwCancelHov.containsMouse ? "#1e2535" : "#16191f"
                    border.color: "#2a3040"; border.width: 1
                    Text { anchors.centerIn: parent; text: "Cancel"; color: "#8090a8"; font.pixelSize: 12 }
                    HoverHandler { id: pwCancelHov }
                    TapHandler {
                        onTapped: { pwField.text = ""; pwError.visible = false; passwordPrompt.close() }
                    }
                }

                Rectangle {
                    width: 90; height: 32; radius: 7
                    color: pwOkHov.containsMouse ? "#2a7aff" : "#1a5aee"
                    Text { anchors.centerIn: parent; text: "Unlock"; color: "#fff"; font.pixelSize: 12; font.weight: Font.Bold }
                    HoverHandler { id: pwOkHov }
                    TapHandler { onTapped: passwordPrompt.checkPassword() }
                }
            }
        }

        function checkPassword() {
            if (pwField.text === root._hiddenPassword) {
                pwField.text = ""
                pwError.visible = false
                passwordPrompt.close()
                root._hiddenUnlocked = true
                hiddenOverlay.visible = true
            } else {
                pwError.visible = true
                pwField.selectAll()
                pwField.forceActiveFocus()
            }
        }
    }
}
