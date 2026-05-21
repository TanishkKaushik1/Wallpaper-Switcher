import QtQuick
import QtQuick.Controls
import "../services"

// Slide-out settings panel anchored to the right edge of its parent.
// Usage: set `targetWallpaperId` and `targetWallpaperPath`, then set `open: true`.
// Emits `applyRequested(workshopId, wallpaperPath)` when Save & Apply is clicked.
Item {
    id: panel

    // ── Public ────────────────────────────────────────────────────────────
    property bool   open:                false
    property string targetWallpaperId:   ""
    property string targetWallpaperPath: ""

    signal applyRequested(string workshopId, string wallpaperPath)

    // ── Geometry ──────────────────────────────────────────────────────────
    anchors.fill: parent

    // Dim overlay
    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: panel.open ? 0.45 : 0.0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 220 } }

        TapHandler { onTapped: panel.open = false }
    }

    // ── Drawer ────────────────────────────────────────────────────────────
    Rectangle {
        id: drawer
        width: 320
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.rightMargin: panel.open ? 0 : -width

        color: "#10121a"
        border.color: "#1a1e2a"
        border.width: 1

        Behavior on anchors.rightMargin {
            NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
        }

        // Left accent line
        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 2
            color: "#1a6aff"
            opacity: 0.7
        }

        // ── Inner scroll area ─────────────────────────────────────────────
        Flickable {
            id: flick
            anchors.fill: parent
            anchors.leftMargin: 2   // clear accent line
            contentHeight: col.implicitHeight + 32
            clip: true

            Column {
                id: col
                width: flick.width
                spacing: 0

                // ── Header ────────────────────────────────────────────────
                Item {
                    width: parent.width
                    height: 64

                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width; height: 1
                        color: "#1a1e2a"
                    }

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: 20
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 10

                        Text {
                            text: "⚙"
                            color: "#1a6aff"
                            font.pixelSize: 16
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2
                            Text {
                                text: "LWE SETTINGS"
                                color: "#ffffff"
                                font.pixelSize: 11
                                font.family: "monospace"
                                font.letterSpacing: 2.5
                                font.weight: Font.Bold
                            }
                            Text {
                                text: panel.targetWallpaperId !== ""
                                    ? "ID: " + panel.targetWallpaperId
                                    : "no wallpaper selected"
                                color: "#3a4a6a"
                                font.pixelSize: 9
                                font.family: "monospace"
                                font.letterSpacing: 0.5
                            }
                        }
                    }

                    // Close button
                    Rectangle {
                        anchors.right: parent.right
                        anchors.rightMargin: 16
                        anchors.verticalCenter: parent.verticalCenter
                        width: 28; height: 28; radius: 6
                        color: closeH.containsMouse ? "#2a1a1a" : "transparent"
                        border.color: closeH.containsMouse ? "#ff4444" : "#2a2f3a"
                        border.width: 1
                        Behavior on color       { ColorAnimation { duration: 130 } }
                        Behavior on border.color{ ColorAnimation { duration: 130 } }

                        Text {
                            anchors.centerIn: parent
                            text: "✕"
                            color: closeH.containsMouse ? "#ff4444" : "#555"
                            font.pixelSize: 11
                        }
                        HoverHandler { id: closeH }
                        TapHandler   { onTapped: panel.open = false }
                    }
                }

                // ── Section: Audio ─────────────────────────────────────────
                SettingsSectionLabel { label: "AUDIO" }

                // Volume
                SettingsRow {
                    label: "Volume"
                    sublabel: "--volume"
                    enabled: !LweSettingsService.mute

                    Row {
                        spacing: 8
                        anchors.verticalCenter: parent.verticalCenter

                        Slider {
                            id: volSlider
                            from: 0; to: 100
                            value: LweSettingsService.volume
                            enabled: !LweSettingsService.mute
                            width: 140
                            anchors.verticalCenter: parent.verticalCenter
                            onMoved: LweSettingsService.volume = Math.round(value)

                            background: Rectangle {
                                x: volSlider.leftPadding
                                y: volSlider.topPadding + volSlider.availableHeight / 2 - height / 2
                                width: volSlider.availableWidth; height: 3; radius: 2
                                color: "#1e2535"
                                Rectangle {
                                    width: volSlider.visualPosition * parent.width
                                    height: parent.height; radius: 2
                                    color: volSlider.enabled ? "#1a6aff" : "#2a3040"
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                }
                            }
                            handle: Rectangle {
                                x: volSlider.leftPadding + volSlider.visualPosition * (volSlider.availableWidth - width)
                                y: volSlider.topPadding + volSlider.availableHeight / 2 - height / 2
                                width: 14; height: 14; radius: 7
                                color: volSlider.enabled ? (volSlider.pressed ? "#2a7aff" : "#1a6aff") : "#2a3040"
                                border.color: volSlider.enabled ? "#4a8aff" : "#1e2535"
                                border.width: 1
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }
                        }

                        Text {
                            text: LweSettingsService.volume + "%"
                            color: LweSettingsService.mute ? "#2a3040" : "#6a8acc"
                            font.pixelSize: 10; font.family: "monospace"
                            width: 34; horizontalAlignment: Text.AlignRight
                            anchors.verticalCenter: parent.verticalCenter
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }
                    }
                }

                // Mute
                SettingsRow {
                    label: "Mute"
                    sublabel: "--noaudio"
                    ToggleSwitch {
                        checked: LweSettingsService.mute
                        anchors.verticalCenter: parent.verticalCenter
                        onToggled: LweSettingsService.mute = checked
                    }
                }

                // ── Section: Display ───────────────────────────────────────
                SettingsSectionLabel { label: "DISPLAY" }

                // Scaling
                SettingsRow {
                    label: "Scaling"
                    sublabel: "--scaling"
                    OptionPicker {
                        model: ["fill", "fit", "stretch", "default"]
                        currentValue: LweSettingsService.scaling
                        anchors.verticalCenter: parent.verticalCenter
                        onPicked: function(v) { LweSettingsService.scaling = v }
                    }
                }

                // FPS cap
                SettingsRow {
                    label: "FPS cap"
                    sublabel: "--fps"

                    Row {
                        spacing: 8
                        anchors.verticalCenter: parent.verticalCenter

                        Slider {
                            id: fpsSlider
                            from: 10; to: 144
                            value: LweSettingsService.fps
                            width: 140
                            stepSize: 1
                            anchors.verticalCenter: parent.verticalCenter
                            onMoved: LweSettingsService.fps = Math.round(value)

                            background: Rectangle {
                                x: fpsSlider.leftPadding
                                y: fpsSlider.topPadding + fpsSlider.availableHeight / 2 - height / 2
                                width: fpsSlider.availableWidth; height: 3; radius: 2
                                color: "#1e2535"
                                Rectangle {
                                    width: fpsSlider.visualPosition * parent.width
                                    height: parent.height; radius: 2
                                    color: "#1a6aff"
                                }
                            }
                            handle: Rectangle {
                                x: fpsSlider.leftPadding + fpsSlider.visualPosition * (fpsSlider.availableWidth - width)
                                y: fpsSlider.topPadding + fpsSlider.availableHeight / 2 - height / 2
                                width: 14; height: 14; radius: 7
                                color: fpsSlider.pressed ? "#2a7aff" : "#1a6aff"
                                border.color: "#4a8aff"; border.width: 1
                            }
                        }

                        Text {
                            text: LweSettingsService.fps
                            color: "#6a8acc"
                            font.pixelSize: 10; font.family: "monospace"
                            width: 34; horizontalAlignment: Text.AlignRight
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }

                // hwdec
                SettingsRow {
                    label: "HW decode"
                    sublabel: "--mpv-hwdec"
                    OptionPicker {
                        model: ["nvdec", "auto", "no"]
                        currentValue: LweSettingsService.hwdec
                        anchors.verticalCenter: parent.verticalCenter
                        onPicked: function(v) { LweSettingsService.hwdec = v }
                    }
                }

                // Screen
                SettingsRow {
                    label: "Screen"
                    sublabel: "--screen-root"

                    Rectangle {
                        width: 110; height: 28; radius: 5
                        color: "#0d0e14"
                        border.color: screenField.activeFocus ? "#1a6aff" : "#1e2535"
                        border.width: 1
                        anchors.verticalCenter: parent.verticalCenter
                        Behavior on border.color { ColorAnimation { duration: 130 } }

                        TextInput {
                            id: screenField
                            anchors.fill: parent
                            anchors.margins: 8
                            text: LweSettingsService.screen
                            color: "#c0c8e0"
                            font.pixelSize: 11; font.family: "monospace"
                            selectionColor: "#1a6aff"
                            selectedTextColor: "#ffffff"
                            onEditingFinished: LweSettingsService.screen = text
                        }
                    }
                }

                // ── Section: Input ─────────────────────────────────────────
                SettingsSectionLabel { label: "INPUT" }

                // Disable mouse
                SettingsRow {
                    label: "Disable mouse"
                    sublabel: "--no-mouse-input"
                    ToggleSwitch {
                        checked: LweSettingsService.disableMouse
                        anchors.verticalCenter: parent.verticalCenter
                        onToggled: LweSettingsService.disableMouse = checked
                    }
                }

                // Pause on focus
                SettingsRow {
                    label: "Pause on focus"
                    sublabel: "--disable-mouse-input"
                    ToggleSwitch {
                        checked: LweSettingsService.pauseOnFocus
                        anchors.verticalCenter: parent.verticalCenter
                        onToggled: LweSettingsService.pauseOnFocus = checked
                    }
                }

                // ── Footer: Save & Apply ───────────────────────────────────
                Item { width: parent.width; height: 20 }

                Rectangle {
                    width: parent.width - 40
                    height: 1
                    color: "#1a1e2a"
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Item { width: parent.width; height: 16 }

                // Save & Apply button
                Rectangle {
                    id: applyBtn
                    width: parent.width - 40
                    height: 40; radius: 8
                    anchors.horizontalCenter: parent.horizontalCenter
                    color: applyBtnH.containsMouse ? "#2a7aff" : "#1a6aff"
                    Behavior on color { ColorAnimation { duration: 130 } }

                    Row {
                        anchors.centerIn: parent; spacing: 8
                        Text {
                            text: "▶"
                            color: "#fff"; font.pixelSize: 9
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: "SAVE & APPLY"
                            color: "#fff"; font.pixelSize: 11
                            font.family: "monospace"; font.letterSpacing: 1.8
                            font.weight: Font.Bold
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    HoverHandler { id: applyBtnH }
                    TapHandler {
                        onTapped: {
                            LweSettingsService.save()
                            if (panel.targetWallpaperPath !== "")
                                panel.applyRequested(panel.targetWallpaperId, panel.targetWallpaperPath)
                            panel.open = false
                        }
                    }
                }

                // Save only button
                Rectangle {
                    width: parent.width - 40
                    height: 34; radius: 8
                    anchors.horizontalCenter: parent.horizontalCenter
                    color: saveOnlyH.containsMouse ? "#1a2035" : "transparent"
                    border.color: saveOnlyH.containsMouse ? "#1a6aff" : "#1e2535"
                    border.width: 1
                    Behavior on color       { ColorAnimation { duration: 130 } }
                    Behavior on border.color{ ColorAnimation { duration: 130 } }

                    Text {
                        anchors.centerIn: parent
                        text: "SAVE ONLY"
                        color: saveOnlyH.containsMouse ? "#4a8aff" : "#3a4a6a"
                        font.pixelSize: 10; font.family: "monospace"
                        font.letterSpacing: 1.5; font.weight: Font.Bold
                        Behavior on color { ColorAnimation { duration: 130 } }
                    }
                    HoverHandler { id: saveOnlyH }
                    TapHandler   { onTapped: { LweSettingsService.save(); panel.open = false } }
                }

                Item { width: parent.width; height: 20 }
            }
        }
    }

    // ── Internal sub-components ───────────────────────────────────────────

    // Section label separator
    component SettingsSectionLabel: Item {
        property string label: ""
        width: parent.width
        height: 38

        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width; height: 1; color: "#161924"
        }

        Row {
            anchors.left: parent.left
            anchors.leftMargin: 20
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            Rectangle {
                width: 3; height: 10; radius: 1
                color: "#1a6aff"
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: label
                color: "#1a6aff"
                font.pixelSize: 9; font.family: "monospace"
                font.letterSpacing: 2.5; font.weight: Font.Bold
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    // Row container: label on left, control slot on right
    component SettingsRow: Item {
        property string label: ""
        property string sublabel: ""
        default property alias content: controlSlot.data

        width: parent.width
        height: 54

        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width; height: 1; color: "#0f1118"
        }

        Column {
            anchors.left: parent.left
            anchors.leftMargin: 20
            anchors.verticalCenter: parent.verticalCenter
            spacing: 3

            Text {
                text: label
                color: "#9aaac0"
                font.pixelSize: 11; font.family: "monospace"
            }
            Text {
                text: sublabel
                color: "#2a3a58"
                font.pixelSize: 9; font.family: "monospace"
                font.letterSpacing: 0.3
            }
        }

        Item {
            id: controlSlot
            anchors.right: parent.right
            anchors.rightMargin: 20
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 200
        }
    }

    // Toggle switch
    component ToggleSwitch: Item {
        property bool checked: false
        signal toggled(bool checked)

        width: 40; height: 22

        Rectangle {
            anchors.fill: parent; radius: 11
            color: parent.checked ? "#1a6aff" : "#1e2535"
            Behavior on color { ColorAnimation { duration: 150 } }

            Rectangle {
                width: 16; height: 16; radius: 8
                anchors.verticalCenter: parent.verticalCenter
                x: parent.checked ? parent.width - width - 3 : 3
                color: "#ffffff"
                Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
            }
        }

        TapHandler {
            onTapped: {
                parent.checked = !parent.checked
                parent.toggled(parent.checked)
            }
        }
    }

    // Option picker (mini segmented control)
    component OptionPicker: Item {
        property var    model:        []
        property string currentValue: ""
        signal picked(string value)

        width: row.implicitWidth; height: 28

        Row {
            id: row
            spacing: 2

            Repeater {
                model: parent.parent.model
                delegate: Rectangle {
                    property bool active: modelData === currentValue
                    height: 28
                    width: optText.width + 14
                    radius: 5
                    color: active ? "#1a2a4a" : (optH.containsMouse ? "#161924" : "transparent")
                    border.color: active ? "#1a6aff" : (optH.containsMouse ? "#2a3a58" : "#1e2535")
                    border.width: 1
                    Behavior on color       { ColorAnimation { duration: 120 } }
                    Behavior on border.color{ ColorAnimation { duration: 120 } }

                    Text {
                        id: optText
                        anchors.centerIn: parent
                        text: modelData
                        color: active ? "#4a8aff" : (optH.containsMouse ? "#6a8aaa" : "#3a4a66")
                        font.pixelSize: 10; font.family: "monospace"
                        font.letterSpacing: 0.5; font.weight: active ? Font.Bold : Font.Normal
                        Behavior on color { ColorAnimation { duration: 120 } }
                    }
                    HoverHandler { id: optH }
                    TapHandler   { onTapped: picked(modelData) }
                }
            }
        }
    }
}
