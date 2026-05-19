import QtQuick
import QtQuick.Controls

Rectangle {
    id: root

    property alias text: input.text

    height: 34
    radius: 6
    color: input.activeFocus ? "#14182a" : "#10121a"
    border.color: input.activeFocus ? "#1a6aff" : "#1e2230"
    border.width: 1

    Behavior on color        { ColorAnimation { duration: 150 } }
    Behavior on border.color { ColorAnimation { duration: 150 } }

    Row {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 10

        Text {
            text: "⌕"
            color: input.activeFocus ? "#4a7aff" : "#3a4050"
            font.pixelSize: 16
            anchors.verticalCenter: parent.verticalCenter
            Behavior on color { ColorAnimation { duration: 150 } }
        }

        TextInput {
            id: input
            width: parent.width - 40
            anchors.verticalCenter: parent.verticalCenter
            color: "#d0d8f0"
            font.pixelSize: 12
            font.family: "monospace"
            font.letterSpacing: 0.3
            selectionColor: "#1a4aaa"
            selectedTextColor: "#ffffff"
            clip: true

            // Placeholder text
            Text {
                anchors.fill: parent
                text: "Search wallpapers by name or ID…"
                color: "#2a3040"
                font.pixelSize: 12
                font.family: "monospace"
                font.letterSpacing: 0.3
                visible: input.text === "" && !input.activeFocus
                verticalAlignment: Text.AlignVCenter
            }

            // alias `text` change signal is emitted automatically when `input.text` changes
        }

        // Clear button
        Text {
            text: "✕"
            color: "#3a4050"
            font.pixelSize: 11
            anchors.verticalCenter: parent.verticalCenter
            visible: input.text !== ""
            opacity: clearHover.containsMouse ? 1.0 : 0.6

            HoverHandler { id: clearHover }
            TapHandler { onTapped: input.text = "" }
        }
    }

    // Click anywhere on the bar to focus
    TapHandler { onTapped: input.forceActiveFocus() }
}
