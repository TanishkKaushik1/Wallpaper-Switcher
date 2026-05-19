import QtQuick
import QtQuick.Controls

Rectangle {
    id: card

    // ── Public ───────────────────────────────────────────────────────────
    property string workshopId: ""
    property string title: ""
    property string wallpaperType: ""
    property string previewPath: ""
    property string folderPath: ""

    signal applyRequested(string workshopId, string wallpaperPath)

    // ── Appearance ────────────────────────────────────────────────────────
    radius: 10
    color: cardHover.containsMouse ? "#16191f" : "#12141a"
    border.color: cardHover.containsMouse ? "#1e4aaa" : "#1a1e28"
    border.width: 1
    clip: true

    Behavior on color        { ColorAnimation { duration: 180 } }
    Behavior on border.color { ColorAnimation { duration: 180 } }

    // ── Hover handler ─────────────────────────────────────────────────────
    HoverHandler { id: cardHover }

    // ── Preview image ─────────────────────────────────────────────────────
    Rectangle {
        id: imgContainer
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: parent.height - 52
        color: "#0a0c10"
        radius: 8

        // Actual preview image
        Image {
            id: preview
            anchors.fill: parent
            source: card.previewPath !== "" ? ("file://" + card.previewPath) : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            smooth: true
            visible: status === Image.Ready
            layer.enabled: true
            // Slight darkening overlay on hover so apply button pops
            opacity: cardHover.containsMouse ? 0.85 : 1.0
            Behavior on opacity { NumberAnimation { duration: 200 } }
        }

        // Placeholder when no preview / loading
        Column {
            anchors.centerIn: parent
            spacing: 8
            visible: preview.status !== Image.Ready

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: {
                    if (card.wallpaperType === "video")   return "▶"
                    if (card.wallpaperType === "web")     return "◈"
                    if (card.wallpaperType === "scene")   return "✦"
                    return "◇"
                }
                color: "#2a3040"
                font.pixelSize: 28
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: card.wallpaperType.toUpperCase()
                color: "#2a3040"
                font.pixelSize: 9
                font.family: "monospace"
                font.letterSpacing: 2
                visible: card.wallpaperType !== ""
            }
        }

        // Type badge (top-right corner)
        Rectangle {
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: 6
            width: typeLabel.width + 10
            height: 18
            radius: 4
            color: "#0d0e10"
            opacity: 0.85
            visible: card.wallpaperType !== ""

            Text {
                id: typeLabel
                anchors.centerIn: parent
                text: card.wallpaperType.toUpperCase()
                color: {
                    if (card.wallpaperType === "video") return "#ff9944"
                    if (card.wallpaperType === "web")   return "#44aaff"
                    if (card.wallpaperType === "scene") return "#44ff99"
                    return "#aaaaaa"
                }
                font.pixelSize: 8
                font.letterSpacing: 1.5
                font.family: "monospace"
                font.weight: Font.Bold
            }
        }

        // ── Apply button — appears on hover ───────────────────────────────
        Rectangle {
            anchors.centerIn: parent
            width: 90; height: 32
            radius: 6
            color: applyHover.containsMouse ? "#2a7aff" : "#1a6aff"
            opacity: cardHover.containsMouse ? 1.0 : 0.0
            visible: opacity > 0

            Behavior on opacity { NumberAnimation { duration: 200 } }
            Behavior on color   { ColorAnimation  { duration: 120 } }

            Row {
                anchors.centerIn: parent
                spacing: 6

                Text {
                    text: "▶"
                    color: "#ffffff"
                    font.pixelSize: 9
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: "APPLY"
                    color: "#ffffff"
                    font.pixelSize: 11
                    font.letterSpacing: 1.5
                    font.family: "monospace"
                    font.weight: Font.Bold
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            HoverHandler { id: applyHover }
            TapHandler {
                onTapped: card.applyRequested(card.workshopId, card.folderPath)
            }
        }
    }

    // ── Bottom info strip ─────────────────────────────────────────────────
    Item {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 52
        anchors.leftMargin: 10
        anchors.rightMargin: 10

        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            spacing: 2

            Text {
                width: parent.width
                text: card.title
                color: cardHover.containsMouse ? "#e0e6ff" : "#b0b8cc"
                font.pixelSize: 12
                font.weight: Font.Medium
                elide: Text.ElideRight
                Behavior on color { ColorAnimation { duration: 180 } }
            }

            Text {
                text: "ID: " + card.workshopId
                color: "#3a4458"
                font.pixelSize: 10
                font.family: "monospace"
                font.letterSpacing: 0.3
            }
        }
    }
}
