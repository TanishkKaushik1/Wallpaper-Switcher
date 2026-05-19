import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"

Item {
    id: root

    // ── Public ───────────────────────────────────────────────────────────
    property var model: null
    property string filterText: ""
    signal applyRequested(string workshopId, string wallpaperPath)

    // ── Filtered proxy ────────────────────────────────────────────────────
    // We use a plain JS array rebuilt whenever model or filter changes.
    property var filteredItems: []

    function rebuildFilter() {
        if (!model) { filteredItems = []; return }
        var ft = filterText.toLowerCase()
        var arr = []
        for (var i = 0; i < model.count; i++) {
            var item = model.get(i)
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

    onFilterTextChanged: rebuildFilter()
    onModelChanged: {
        if (model) model.countChanged.connect(rebuildFilter)
        rebuildFilter()
    }

    // ── Empty state ────────────────────────────────────────────────────────
    Column {
        anchors.centerIn: parent
        spacing: 16
        visible: root.filteredItems.length === 0

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "◈"
            color: "#2a2f3a"
            font.pixelSize: 48
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.filterText !== "" ? "No results for \"" + root.filterText + "\"" : "No wallpapers found"
            color: "#3a4050"
            font.pixelSize: 13
            font.family: "monospace"
            font.letterSpacing: 0.5
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.filterText === "" ? "Make sure Steam Workshop wallpapers are downloaded" : ""
            color: "#2a3040"
            font.pixelSize: 11
            font.family: "monospace"
        }
    }

    // ── Grid ───────────────────────────────────────────────────────────────
    ScrollView {
        anchors.fill: parent
        anchors.margins: 20
        ScrollBar.horizontal: ScrollBar { policy: ScrollBar.AlwaysOff }
        clip: true

        // Style the scrollbar
        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
            width: 4
            contentItem: Rectangle {
                radius: 2
                color: "#2a6aff"
                opacity: 0.7
            }
            background: Rectangle {
                color: "#1a1e26"
                radius: 2
            }
        }

        GridView {
            id: grid
            width: root.width - 40

            cellWidth: 240
            cellHeight: 200

            model: root.filteredItems.length

            delegate: Item {
                width: grid.cellWidth
                height: grid.cellHeight

                WallpaperCard {
                    anchors.fill: parent
                    anchors.margins: 8

                    workshopId:    root.filteredItems[index].workshopId
                    title:         root.filteredItems[index].title
                    wallpaperType: root.filteredItems[index].wallpaperType
                    previewPath:   root.filteredItems[index].previewPath
                    folderPath:    root.filteredItems[index].folderPath

                    onApplyRequested: function(wid, wpath) {
                        root.applyRequested(wid, wpath)
                    }
                }
            }
        }
    }
}
