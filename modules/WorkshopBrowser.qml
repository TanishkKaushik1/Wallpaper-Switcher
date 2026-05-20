import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

// ── WorkshopBrowser ──────────────────────────────────────────────────────────
// Place this file in your modules/ folder alongside WallpaperGrid.qml.
// The two Python helpers (workshop_search.py, workshop_download.py) go in
// the project root (same level as shell.qml).
Item {
    id: root

    // Passed in from WallpaperSwitcherWindow — mirrors WallpaperService.workshopRoot
    property string workshopRoot:
        "/home/tanishk/.local/share/Steam/steamapps/workshop/content/431960"

    // Resolved at runtime: parent folder of this QML file → project root
    // WorkshopBrowser lives in modules/, scripts live one level up in root
    readonly property string _scriptDir: {
        var u = Qt.resolvedUrl("../workshop_search.py").toString()
        return u.replace("file://", "").replace(/\/workshop_search\.py$/, "")
    }

    // ── State ─────────────────────────────────────────────────────────────
    property var results: []
    property bool loading: false
    property string statusMsg: ""
    property int currentPage: 1
    property string lastQuery: ""

    // ── Search process ────────────────────────────────────────────────────
    property var _searchProc: Process {
        id: searchProc
        property string _buf: ""
        onStarted: _buf = ""
        stdout: SplitParser { onRead: function(l) { searchProc._buf += l } }
        stderr: SplitParser { onRead: function(l) { searchProc._buf += l } }
        onExited: function(code) {
            root.loading = false
            if (code !== 0 || searchProc._buf.trim() === "") {
                root.statusMsg = "Search failed — check internet connection"
                return
            }
            try {
                var arr = JSON.parse(searchProc._buf.trim())
                if (arr.error) { root.statusMsg = "API error: " + arr.error; return }
                root.results = arr
                root.statusMsg = arr.length > 0 ? arr.length + " results" : "No results found"
            } catch(e) {
                root.statusMsg = "Parse error: " + e
            }
        }
    }

    // ── Download/open process ─────────────────────────────────────────────
    property var _dlProc: Process {
        id: dlProc
        property string _buf: ""
        onStarted: _buf = ""
        stdout: SplitParser { onRead: function(l) { dlProc._buf += l } }
        stderr: SplitParser { onRead: function(l) { dlProc._buf += l } }
        onExited: function() {
            var out = dlProc._buf.trim()
            if (out.indexOf("already_downloaded") === 0)
                root.statusMsg = "✓ Already in your library — go to Library tab"
            else if (out.indexOf("opening_steam") === 0)
                root.statusMsg = "Steam opened → Subscribe → then Refresh Library"
            else
                root.statusMsg = "Error: " + out
        }
    }

    // ── Functions ─────────────────────────────────────────────────────────
    function doSearch(query, page) {
        if (loading || query.trim() === "") return
        loading = true
        lastQuery = query
        currentPage = page
        statusMsg = "Searching…"
        results = []
        searchProc.command = ["python3", root._scriptDir + "/workshop_search.py", query, String(page)]
        searchProc.running = true
    }

    function openInSteam(wid) {
        dlProc._buf = ""
        dlProc.command = ["python3", root._scriptDir + "/workshop_download.py", wid, root.workshopRoot]
        dlProc.running = true
        statusMsg = "Checking…"
    }

    // ── UI ─────────────────────────────────────────────────────────────────
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 12

        // ── Search bar ────────────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            height: 44
            radius: 8
            color: "#0f1118"
            border.color: wsInput.activeFocus ? "#1a6aff" : "#1a1e28"
            border.width: 1
            Behavior on border.color { ColorAnimation { duration: 150 } }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 8
                spacing: 8

                Text {
                    text: "⌕"
                    color: "#3a4458"
                    font.pixelSize: 18
                    Layout.alignment: Qt.AlignVCenter
                }

                TextInput {
                    id: wsInput
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    color: "#c8d0e8"
                    font.pixelSize: 13
                    font.family: "monospace"
                    selectionColor: "#2a6aff"
                    clip: true

                    Text {
                        anchors.fill: parent
                        text: "Search Workshop… anime, lofi, cyberpunk, nature…"
                        color: "#2a3040"
                        font: parent.font
                        visible: parent.text === "" && !parent.activeFocus
                    }

                    Keys.onReturnPressed: root.doSearch(text, 1)
                    Keys.onEnterPressed:  root.doSearch(text, 1)
                }

                // GO button
                Rectangle {
                    width: 60; height: 32
                    radius: 6
                    color: goBtnH.containsMouse ? "#2a7aff" : "#1a6aff"
                    Behavior on color { ColorAnimation { duration: 120 } }
                    Layout.alignment: Qt.AlignVCenter

                    Text {
                        anchors.centerIn: parent
                        text: root.loading ? "…" : "GO"
                        color: "#ffffff"
                        font.pixelSize: 11
                        font.family: "monospace"
                        font.weight: Font.Bold
                        font.letterSpacing: 1.5
                    }

                    HoverHandler { id: goBtnH }
                    TapHandler { onTapped: root.doSearch(wsInput.text, 1) }
                }
            }
        }

        // ── Quick filter chips ────────────────────────────────────────────
        Row {
            Layout.fillWidth: true
            spacing: 8

            Repeater {
                model: ["anime", "lofi", "nature", "cyberpunk", "abstract", "genshin", "4K", "minimal"]
                delegate: Rectangle {
                    height: 26
                    width: chipLbl.width + 18
                    radius: 13
                    color: chipH.containsMouse ? "#1a2a4a" : "#0f1520"
                    border.color: chipH.containsMouse ? "#2a6aff" : "#1a2030"
                    border.width: 1
                    Behavior on color        { ColorAnimation { duration: 120 } }
                    Behavior on border.color { ColorAnimation { duration: 120 } }

                    Text {
                        id: chipLbl
                        anchors.centerIn: parent
                        text: modelData
                        color: chipH.containsMouse ? "#6a9aff" : "#3a4a60"
                        font.pixelSize: 10
                        font.family: "monospace"
                        font.letterSpacing: 0.8
                        Behavior on color { ColorAnimation { duration: 120 } }
                    }

                    HoverHandler { id: chipH }
                    TapHandler {
                        onTapped: {
                            wsInput.text = modelData
                            root.doSearch(modelData, 1)
                        }
                    }
                }
            }
        }

        // ── Status row ────────────────────────────────────────────────────
        Row {
            spacing: 8
            visible: root.statusMsg !== "" || root.loading

            Rectangle {
                width: 6; height: 6; radius: 3
                anchors.verticalCenter: parent.verticalCenter
                color: root.loading ? "#ffaa44" : "#44cc77"
                SequentialAnimation on opacity {
                    running: root.loading
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.2; duration: 500 }
                    NumberAnimation { to: 1.0; duration: 500 }
                }
            }

            Text {
                text: root.statusMsg
                color: "#4a5a70"
                font.pixelSize: 11
                font.family: "monospace"
                font.letterSpacing: 0.4
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        // ── Results grid ──────────────────────────────────────────────────
        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            ScrollBar.horizontal: ScrollBar { policy: ScrollBar.AlwaysOff }
            clip: true

            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
                width: 4
                contentItem: Rectangle { radius: 2; color: "#2a6aff"; opacity: 0.7 }
                background: Rectangle { color: "#1a1e26"; radius: 2 }
            }

            // Empty / landing state
            Column {
                anchors.centerIn: parent
                spacing: 16
                visible: root.results.length === 0 && !root.loading

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "⬡"
                    color: "#181e28"
                    font.pixelSize: 56
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Browse the Steam Workshop"
                    color: "#2a3040"
                    font.pixelSize: 13
                    font.family: "monospace"
                    font.letterSpacing: 0.5
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Search above or tap a quick filter chip"
                    color: "#1a2030"
                    font.pixelSize: 11
                    font.family: "monospace"
                }
            }

            GridView {
                id: resultsGrid
                width: root.width - 40
                cellWidth: 220
                cellHeight: 215
                model: root.results.length

                delegate: Item {
                    width: resultsGrid.cellWidth
                    height: resultsGrid.cellHeight

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 8
                        radius: 10
                        color: cardH.containsMouse ? "#16191f" : "#0f1118"
                        border.color: cardH.containsMouse ? "#1e4aaa" : "#141820"
                        border.width: 1
                        clip: true
                        Behavior on color        { ColorAnimation { duration: 180 } }
                        Behavior on border.color { ColorAnimation { duration: 180 } }

                        HoverHandler { id: cardH }

                        property var item: root.results[index] || {}

                        // ── Preview image ─────────────────────────────────
                        Rectangle {
                            id: imgBox
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: parent.height - 60
                            color: "#08090d"
                            radius: 8

                            Image {
                                anchors.fill: parent
                                source: parent.parent.item.previewUrl || ""
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                smooth: true
                                visible: status === Image.Ready
                                opacity: cardH.containsMouse ? 0.75 : 1.0
                                Behavior on opacity { NumberAnimation { duration: 200 } }
                            }

                            // Placeholder icon
                            Text {
                                anchors.centerIn: parent
                                text: {
                                    var t = parent.parent.item.wallpaperType || ""
                                    if (t === "scene") return "✦"
                                    if (t === "video") return "▶"
                                    if (t === "web")   return "◈"
                                    return "◇"
                                }
                                color: "#1a2030"
                                font.pixelSize: 28
                                visible: parent.children[0].status !== Image.Ready
                            }

                            // Type badge
                            Rectangle {
                                anchors.top: parent.top
                                anchors.right: parent.right
                                anchors.margins: 6
                                width: badgeTxt.width + 10
                                height: 18
                                radius: 4
                                color: "#0a0b0e"
                                opacity: 0.9
                                visible: (parent.parent.item.wallpaperType || "") !== ""

                                Text {
                                    id: badgeTxt
                                    anchors.centerIn: parent
                                    text: (parent.parent.item.wallpaperType || "").toUpperCase()
                                    color: {
                                        var t = parent.parent.item.wallpaperType || ""
                                        if (t === "video") return "#ff9944"
                                        if (t === "web")   return "#44aaff"
                                        if (t === "scene") return "#44ff99"
                                        return "#aaaaaa"
                                    }
                                    font.pixelSize: 8
                                    font.letterSpacing: 1.5
                                    font.family: "monospace"
                                    font.weight: Font.Bold
                                }
                            }

                            // GET IN STEAM button
                            Rectangle {
                                anchors.centerIn: parent
                                width: 126; height: 34
                                radius: 6
                                color: dlH.containsMouse ? "#22cc77" : "#18aa66"
                                opacity: cardH.containsMouse ? 1.0 : 0.0
                                visible: opacity > 0
                                Behavior on opacity { NumberAnimation { duration: 200 } }
                                Behavior on color   { ColorAnimation  { duration: 120 } }

                                Row {
                                    anchors.centerIn: parent
                                    spacing: 6
                                    Text {
                                        text: "↓"
                                        color: "#ffffff"
                                        font.pixelSize: 14
                                        font.weight: Font.Bold
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    Text {
                                        text: "GET IN STEAM"
                                        color: "#ffffff"
                                        font.pixelSize: 9
                                        font.letterSpacing: 1.2
                                        font.family: "monospace"
                                        font.weight: Font.Bold
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }

                                HoverHandler { id: dlH }
                                TapHandler {
                                    onTapped: root.openInSteam(parent.parent.parent.item.workshopId)
                                }
                            }
                        }

                        // ── Info strip ────────────────────────────────────
                        Item {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            height: 60
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10

                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width
                                spacing: 4

                                Text {
                                    width: parent.width
                                    text: parent.parent.parent.item.title || ""
                                    color: cardH.containsMouse ? "#e0e6ff" : "#a0a8bc"
                                    font.pixelSize: 11
                                    font.weight: Font.Medium
                                    elide: Text.ElideRight
                                    Behavior on color { ColorAnimation { duration: 180 } }
                                }

                                Row {
                                    spacing: 10
                                    Text {
                                        text: "★ " + ((parent.parent.parent.item.subscriptions || 0) > 999
                                            ? (Math.floor((parent.parent.parent.item.subscriptions || 0) / 1000)) + "k"
                                            : (parent.parent.parent.item.subscriptions || 0))
                                        color: "#ffaa44"
                                        font.pixelSize: 9
                                        font.family: "monospace"
                                    }
                                    Text {
                                        text: "ID " + (parent.parent.parent.item.workshopId || "")
                                        color: "#2a3448"
                                        font.pixelSize: 9
                                        font.family: "monospace"
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // ── Pagination ────────────────────────────────────────────────────
        Row {
            Layout.alignment: Qt.AlignHCenter
            spacing: 12
            visible: root.results.length > 0 || root.currentPage > 1

            Rectangle {
                width: 80; height: 30; radius: 6
                color: prevH.containsMouse ? "#1a2a3a" : "#0f1520"
                border.color: root.currentPage > 1 ? "#1e3a5a" : "#0f1520"
                border.width: 1
                opacity: root.currentPage > 1 ? 1.0 : 0.3
                Behavior on color { ColorAnimation { duration: 120 } }

                Text {
                    anchors.centerIn: parent
                    text: "← PREV"
                    color: "#4a6a8a"
                    font.pixelSize: 10
                    font.family: "monospace"
                    font.letterSpacing: 1
                }
                HoverHandler { id: prevH }
                TapHandler {
                    onTapped: if (root.currentPage > 1) root.doSearch(root.lastQuery, root.currentPage - 1)
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "PAGE " + root.currentPage
                color: "#2a3a50"
                font.pixelSize: 10
                font.family: "monospace"
                font.letterSpacing: 1.5
            }

            Rectangle {
                width: 80; height: 30; radius: 6
                color: nextH.containsMouse ? "#1a2a3a" : "#0f1520"
                border.color: "#1e3a5a"
                border.width: 1
                Behavior on color { ColorAnimation { duration: 120 } }

                Text {
                    anchors.centerIn: parent
                    text: "NEXT →"
                    color: "#4a6a8a"
                    font.pixelSize: 10
                    font.family: "monospace"
                    font.letterSpacing: 1
                }
                HoverHandler { id: nextH }
                TapHandler {
                    onTapped: if (root.results.length > 0) root.doSearch(root.lastQuery, root.currentPage + 1)
                }
            }
        }
    }
}
