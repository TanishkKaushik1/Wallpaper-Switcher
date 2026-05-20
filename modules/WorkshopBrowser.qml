import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Item {
    id: root

    property string workshopRoot:
        "/home/tanishk/.local/share/Steam/steamapps/workshop/content/431960"

    readonly property string _scriptDir: {
        var u = Qt.resolvedUrl("../workshop_search.py").toString()
        return u.replace("file://", "").replace(/\/workshop_search\.py$/, "")
    }

    property var    results:     []
    property bool   loading:     false
    property string statusMsg:   ""
    property int    currentPage: 1
    property string lastQuery:   ""
    property string resFilter:   ""   // e.g. "4K", "1080p", ""

    // ── Search process ─────────────────────────────────────────────────────
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
                var mapped = arr.map(function(r) {
                    return {
                        workshopId:    r.id            || "",
                        title:         r.title          || "",
                        previewUrl:    r.preview_url    || "",
                        author:        r.author         || "",
                        subscriptions: r.subscriptions  || 0,
                        resolution:    r.resolution     || "",
                        wallpaperType: r.type           || "",
                        url:           r.url            || ""
                    }
                })
                root.results = mapped
                root.statusMsg = mapped.length > 0 ? mapped.length + " results" : "No results found"
            } catch(e) {
                root.statusMsg = "Parse error: " + e
            }
        }
    }

    // ── Download process ───────────────────────────────────────────────────
    property var _dlProc: Process {
        id: dlProc
        property string _buf: ""
        onStarted: _buf = ""
        stdout: SplitParser { onRead: function(l) { dlProc._buf += l } }
        stderr: SplitParser { onRead: function(l) { dlProc._buf += l } }
        onExited: function() {
            var out = dlProc._buf.trim()
            if (out === "already_downloaded")
                root.statusMsg = "✓ Already in your library"
            else if (out === "downloading")
                root.statusMsg = "⬇ Downloading… check Library in a moment"
            else if (out === "opening_steam")
                root.statusMsg = "Steam opened → Subscribe → Refresh Library"
            else
                root.statusMsg = "⚠ " + out
        }
    }

    // ── Functions ──────────────────────────────────────────────────────────
    function doSearch(query, page) {
        if (loading || query.trim() === "") return
        loading    = true
        lastQuery  = query
        currentPage = page
        statusMsg  = "Searching…"
        results    = []
        var args = ["python3", root._scriptDir + "/workshop_search.py", query, String(page)]
        if (root.resFilter !== "") args.push(root.resFilter)
        searchProc.command = args
        searchProc.running = true
    }

    function downloadWallpaper(wid) {
        if (wid === "") return
        dlProc._buf = ""
        dlProc.command = ["python3", root._scriptDir + "/workshop_download.py", wid, root.workshopRoot]
        dlProc.running = true
        statusMsg = "Checking…"
    }

    // ── UI ─────────────────────────────────────────────────────────────────
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 10

        // ── Search bar row ─────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

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
                            text: "Search Workshop… anime, lofi, cyberpunk…"
                            color: "#2a3040"
                            font: parent.font
                            visible: parent.text === "" && !parent.activeFocus
                            verticalAlignment: Text.AlignVCenter
                        }

                        Keys.onReturnPressed: root.doSearch(text, 1)
                        Keys.onEnterPressed:  root.doSearch(text, 1)
                    }

                    Rectangle {
                        width: 60; height: 32; radius: 6
                        color: goBtnH.containsMouse ? "#2a7aff" : "#1a6aff"
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Layout.alignment: Qt.AlignVCenter

                        Text {
                            anchors.centerIn: parent
                            text: root.loading ? "…" : "GO"
                            color: "#fff"
                            font.pixelSize: 11
                            font.family: "monospace"
                            font.weight: Font.Bold
                            font.letterSpacing: 1.5
                        }
                        HoverHandler { id: goBtnH }
                        TapHandler   { onTapped: root.doSearch(wsInput.text, 1) }
                    }
                }
            }
        }

        // ── Quick filter chips ─────────────────────────────────────────────
        Flow {
            Layout.fillWidth: true
            spacing: 6

            Repeater {
                model: ["anime", "lofi", "nature", "cyberpunk", "abstract", "genshin", "minimal", "city", "space"]
                delegate: Rectangle {
                    height: 24; width: chipLbl.width + 16; radius: 12
                    color: chipH.containsMouse ? "#1a2a4a" : "#0f1520"
                    border.color: chipH.containsMouse ? "#2a6aff" : "#1a2030"
                    border.width: 1
                    Behavior on color        { ColorAnimation { duration: 120 } }
                    Behavior on border.color { ColorAnimation { duration: 120 } }
                    Text {
                        id: chipLbl; anchors.centerIn: parent; text: modelData
                        color: chipH.containsMouse ? "#6a9aff" : "#3a4a60"
                        font.pixelSize: 10; font.family: "monospace"; font.letterSpacing: 0.8
                        Behavior on color { ColorAnimation { duration: 120 } }
                    }
                    HoverHandler { id: chipH }
                    TapHandler { onTapped: { wsInput.text = modelData; root.doSearch(modelData, 1) } }
                }
            }
        }

        // ── Resolution filter ──────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Text {
                text: "RES"
                color: "#2a3448"
                font.pixelSize: 9
                font.family: "monospace"
                font.letterSpacing: 1.5
                Layout.alignment: Qt.AlignVCenter
            }

            Repeater {
                model: ["", "4K", "1080p", "1440p", "ultrawide"]
                delegate: Rectangle {
                    height: 22; width: resLbl.width + 14; radius: 11
                    color: root.resFilter === modelData
                           ? "#1a3a6a"
                           : (resH.containsMouse ? "#151f30" : "#0a0f1a")
                    border.color: root.resFilter === modelData ? "#2a6aff"
                                  : (resH.containsMouse ? "#1a3050" : "#141a24")
                    border.width: 1
                    Behavior on color        { ColorAnimation { duration: 100 } }
                    Behavior on border.color { ColorAnimation { duration: 100 } }
                    Text {
                        id: resLbl; anchors.centerIn: parent
                        text: modelData === "" ? "ALL" : modelData
                        color: root.resFilter === modelData ? "#6aaaff"
                               : (resH.containsMouse ? "#4a6a90" : "#2a3a50")
                        font.pixelSize: 9; font.family: "monospace"; font.letterSpacing: 1
                        Behavior on color { ColorAnimation { duration: 100 } }
                    }
                    HoverHandler { id: resH }
                    TapHandler {
                        onTapped: {
                            root.resFilter = modelData
                            if (root.lastQuery !== "") root.doSearch(root.lastQuery, 1)
                        }
                    }
                }
            }
        }

        // ── Status row ─────────────────────────────────────────────────────
        Row {
            spacing: 8
            visible: root.statusMsg !== "" || root.loading

            Rectangle {
                width: 6; height: 6; radius: 3
                anchors.verticalCenter: parent.verticalCenter
                color: root.loading ? "#ffaa44" : "#44cc77"
                SequentialAnimation on opacity {
                    running: root.loading; loops: Animation.Infinite
                    NumberAnimation { to: 0.2; duration: 500 }
                    NumberAnimation { to: 1.0; duration: 500 }
                }
            }
            Text {
                text: root.statusMsg; color: "#4a5a70"
                font.pixelSize: 11; font.family: "monospace"; font.letterSpacing: 0.4
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        // ── Results grid ───────────────────────────────────────────────────
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            // Empty state
            Column {
                anchors.centerIn: parent
                spacing: 16
                visible: root.results.length === 0 && !root.loading
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: "⬡"; color: "#181e28"; font.pixelSize: 56 }
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Browse the Steam Workshop"; color: "#2a3040"; font.pixelSize: 13; font.family: "monospace" }
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Search above or tap a quick filter chip"; color: "#1a2030"; font.pixelSize: 11; font.family: "monospace" }
            }

            GridView {
                id: resultsGrid
                anchors.fill: parent
                anchors.rightMargin: 8
                cellWidth:  Math.floor(width / Math.max(1, Math.floor(width / 210)))
                cellHeight: 220
                model: root.results.length
                clip: true
                flickableDirection: Flickable.VerticalFlick
                boundsBehavior: Flickable.StopAtBounds

                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                    width: 4
                    contentItem: Rectangle { radius: 2; color: "#2a6aff"; opacity: 0.7 }
                    background: Rectangle { color: "#1a1e26"; radius: 2 }
                }

                delegate: Item {
                    id: cardDelegate
                    width:  resultsGrid.cellWidth
                    height: resultsGrid.cellHeight
                    readonly property var wdata: root.results[index] || {}

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 6
                        radius: 10
                        color: cardH.containsMouse ? "#16191f" : "#0f1118"
                        border.color: cardH.containsMouse ? "#1e4aaa" : "#141820"
                        border.width: 1
                        clip: true
                        Behavior on color        { ColorAnimation { duration: 180 } }
                        Behavior on border.color { ColorAnimation { duration: 180 } }

                        HoverHandler { id: cardH }

                        // ── Thumbnail ──────────────────────────────────────
                        Rectangle {
                            id: imgArea
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: parent.height - 64
                            color: "#08090d"
                            radius: 8
                            clip: true

                            Image {
                                id: thumbImg
                                anchors.fill: parent
                                source: cardDelegate.wdata.previewUrl || ""
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                smooth: true
                                cache: false
                                opacity: cardH.containsMouse ? 0.55 : 1.0
                                Behavior on opacity { NumberAnimation { duration: 200 } }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: "◇"; color: "#1a2030"; font.pixelSize: 28
                                visible: thumbImg.status !== Image.Ready
                            }

                            // Resolution badge
                            Rectangle {
                                anchors.top: parent.top
                                anchors.left: parent.left
                                anchors.margins: 6
                                width: resBadge.width + 10; height: 18; radius: 4
                                color: "#0a0b0e"; opacity: 0.9
                                visible: cardDelegate.wdata.resolution !== ""
                                Text {
                                    id: resBadge
                                    anchors.centerIn: parent
                                    text: cardDelegate.wdata.resolution
                                    color: "#44aaff"
                                    font.pixelSize: 8; font.letterSpacing: 1; font.family: "monospace"; font.weight: Font.Bold
                                }
                            }

                            // ── GET IN STEAM / DOWNLOAD button ─────────────
                            // Uses a MouseArea so it reliably captures clicks on Wayland
                            Rectangle {
                                id: dlBtn
                                anchors.centerIn: parent
                                width: 140; height: 38
                                radius: 7
                                color: dlMouse.containsMouse ? "#22cc77" : "#18aa66"
                                opacity: cardH.containsMouse ? 1.0 : 0.0
                                Behavior on opacity { NumberAnimation { duration: 180 } }
                                Behavior on color   { ColorAnimation  { duration: 120 } }
                                z: 10

                                Row {
                                    anchors.centerIn: parent; spacing: 6
                                    Text { text: "⬇"; color: "#fff"; font.pixelSize: 13; font.weight: Font.Bold; anchors.verticalCenter: parent.verticalCenter }
                                    Text { text: "DOWNLOAD"; color: "#fff"; font.pixelSize: 10; font.letterSpacing: 1.2; font.family: "monospace"; font.weight: Font.Bold; anchors.verticalCenter: parent.verticalCenter }
                                }

                                MouseArea {
                                    id: dlMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.downloadWallpaper(cardDelegate.wdata.workshopId)
                                }
                            }
                        }

                        // ── Info strip ─────────────────────────────────────
                        Item {
                            anchors.left: parent.left; anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            height: 64
                            anchors.leftMargin: 10; anchors.rightMargin: 10

                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width; spacing: 3

                                Text {
                                    width: parent.width
                                    text: cardDelegate.wdata.title || ""
                                    color: cardH.containsMouse ? "#e0e6ff" : "#a0a8bc"
                                    font.pixelSize: 11; font.weight: Font.Medium
                                    elide: Text.ElideRight
                                    Behavior on color { ColorAnimation { duration: 180 } }
                                }
                                Row {
                                    spacing: 8
                                    Text {
                                        text: "★ " + ((cardDelegate.wdata.subscriptions||0) > 999
                                            ? Math.floor((cardDelegate.wdata.subscriptions||0)/1000)+"k"
                                            : (cardDelegate.wdata.subscriptions||0))
                                        color: "#ffaa44"; font.pixelSize: 9; font.family: "monospace"
                                    }
                                    Text {
                                        text: cardDelegate.wdata.author || ""
                                        color: "#3a4a60"; font.pixelSize: 9; font.family: "monospace"
                                        elide: Text.ElideRight; width: 80
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // ── Pagination ─────────────────────────────────────────────────────
        Row {
            Layout.alignment: Qt.AlignHCenter
            spacing: 12
            visible: root.results.length > 0 || root.currentPage > 1

            Rectangle {
                width: 80; height: 30; radius: 6
                color: prevH.containsMouse ? "#1a2a3a" : "#0f1520"
                border.color: root.currentPage > 1 ? "#1e3a5a" : "#0f1520"
                border.width: 1; opacity: root.currentPage > 1 ? 1.0 : 0.3
                Behavior on color { ColorAnimation { duration: 120 } }
                Text { anchors.centerIn: parent; text: "← PREV"; color: "#4a6a8a"; font.pixelSize: 10; font.family: "monospace"; font.letterSpacing: 1 }
                HoverHandler { id: prevH }
                TapHandler { onTapped: if (root.currentPage > 1) root.doSearch(root.lastQuery, root.currentPage - 1) }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "PAGE " + root.currentPage
                color: "#2a3a50"; font.pixelSize: 10; font.family: "monospace"; font.letterSpacing: 1.5
            }

            Rectangle {
                width: 80; height: 30; radius: 6
                color: nextH.containsMouse ? "#1a2a3a" : "#0f1520"
                border.color: "#1e3a5a"; border.width: 1
                Behavior on color { ColorAnimation { duration: 120 } }
                Text { anchors.centerIn: parent; text: "NEXT →"; color: "#4a6a8a"; font.pixelSize: 10; font.family: "monospace"; font.letterSpacing: 1 }
                HoverHandler { id: nextH }
                TapHandler { onTapped: if (root.results.length > 0) root.doSearch(root.lastQuery, root.currentPage + 1) }
            }
        }
    }
}
