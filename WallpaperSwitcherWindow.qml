import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "services"
import "modules"
import "components"

FloatingWindow {
    id: root

    // Window sizing
    width: 1100
    height: 720
    visible: true
    title: "Wallpaper Switcher"

    // ── Background: dark charcoal with subtle grid noise ──────────────────
    color: "#0d0e10"

    // Subtle grid lines background
    Canvas {
        anchors.fill: parent
        opacity: 0.04
        onPaint: {
            var ctx = getContext("2d")
            ctx.strokeStyle = "#ffffff"
            ctx.lineWidth = 1
            var step = 40
            for (var x = 0; x < width; x += step) {
                ctx.beginPath(); ctx.moveTo(x, 0); ctx.lineTo(x, height); ctx.stroke()
            }
            for (var y = 0; y < height; y += step) {
                ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(width, y); ctx.stroke()
            }
        }
    }

    // Accent glow top-left
    Rectangle {
        width: 340; height: 340
        x: -80; y: -80
        radius: 170
        color: "transparent"
        layer.enabled: true
        layer.effect: null
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: "#1a6aff"
            opacity: 0.07
        }
    }

    WallpaperService {
        id: wallpaperService
    }

    // ── Tab state ─────────────────────────────────────────────────────────
    property int activeTab: 0   // 0 = Library, 1 = Workshop

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 0
        spacing: 0

        // ── Header ─────────────────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            height: 64
            color: "#13151a"

            // Bottom border
            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: 1
                color: "#1e2128"
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 24
                anchors.rightMargin: 24
                spacing: 16

                // Logo mark
                Rectangle {
                    width: 32; height: 32
                    radius: 8
                    color: "#1a6aff"
                    Rectangle {
                        width: 16; height: 16
                        anchors.centerIn: parent
                        radius: 4
                        color: "#0d0e10"
                        opacity: 0.6
                    }
                }

                Text {
                    text: "WALLPAPER SWITCHER"
                    color: "#ffffff"
                    font.pixelSize: 13
                    font.letterSpacing: 3
                    font.weight: Font.Bold
                    font.family: "monospace"
                }

                // Wallpaper count badge
                Rectangle {
                    radius: 10
                    width: countText.width + 16
                    height: 22
                    color: "#1e2128"
                    border.color: "#2a2f3a"
                    border.width: 1
                    visible: wallpaperService.wallpapers.count > 0

                    Text {
                        id: countText
                        anchors.centerIn: parent
                        text: wallpaperService.wallpapers.count + " WALLPAPERS"
                        color: "#4a7aff"
                        font.pixelSize: 10
                        font.letterSpacing: 1.5
                        font.family: "monospace"
                        font.weight: Font.Bold
                    }
                }

                Item { Layout.fillWidth: true }

                // Status indicator
                Row {
                    spacing: 8
                    visible: wallpaperService.statusMessage !== ""

                    Rectangle {
                        width: 6; height: 6
                        radius: 3
                        color: wallpaperService.isApplying ? "#ffaa00" : "#00cc66"
                        anchors.verticalCenter: parent.verticalCenter

                        SequentialAnimation on opacity {
                            running: wallpaperService.isApplying
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.2; duration: 600 }
                            NumberAnimation { to: 1.0; duration: 600 }
                        }
                    }

                    Text {
                        text: wallpaperService.statusMessage
                        color: wallpaperService.isApplying ? "#ffaa00" : "#00cc66"
                        font.pixelSize: 11
                        font.family: "monospace"
                        font.letterSpacing: 0.5
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                // Close button
                Rectangle {
                    width: 32; height: 32
                    radius: 6
                    color: closeHover.containsMouse ? "#2a1a1a" : "transparent"
                    border.color: closeHover.containsMouse ? "#ff4444" : "#2a2f3a"
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        color: closeHover.containsMouse ? "#ff4444" : "#666"
                        font.pixelSize: 12
                    }

                    HoverHandler { id: closeHover }
                    TapHandler { onTapped: Qt.quit() }

                    Behavior on color { ColorAnimation { duration: 150 } }
                    Behavior on border.color { ColorAnimation { duration: 150 } }
                }
            }
        }

        // ── Tab bar + contextual toolbar ───────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            height: 56
            color: "#10121a"

            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width; height: 1
                color: "#1a1e26"
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 24
                anchors.rightMargin: 24
                spacing: 12

                // ── Tab buttons ───────────────────────────────────────────
                Row {
                    spacing: 4

                    // LIBRARY tab
                    Rectangle {
                        property bool active: root.activeTab === 0
                        width: libTabLabel.width + 28
                        height: 34
                        radius: 7
                        color: active
                            ? "#1a2035"
                            : (libTabH.containsMouse ? "#13151f" : "transparent")
                        border.color: active ? "#2a4aaa" : "transparent"
                        border.width: 1
                        Behavior on color        { ColorAnimation { duration: 150 } }
                        Behavior on border.color { ColorAnimation { duration: 150 } }

                        Row {
                            anchors.centerIn: parent
                            spacing: 7
                            Text {
                                text: "◧"
                                color: parent.parent.active ? "#4a8aff" : (libTabH.containsMouse ? "#3a5a7a" : "#333a4a")
                                font.pixelSize: 12
                                anchors.verticalCenter: parent.verticalCenter
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }
                            Text {
                                id: libTabLabel
                                text: "LIBRARY"
                                color: parent.parent.active ? "#6a9aff" : (libTabH.containsMouse ? "#3a5a7a" : "#333a4a")
                                font.pixelSize: 10
                                font.family: "monospace"
                                font.letterSpacing: 1.8
                                font.weight: Font.Bold
                                anchors.verticalCenter: parent.verticalCenter
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }
                        }

                        HoverHandler { id: libTabH }
                        TapHandler { onTapped: root.activeTab = 0 }
                    }

                    // WORKSHOP tab
                    Rectangle {
                        property bool active: root.activeTab === 1
                        width: wsTabLabel.width + 28
                        height: 34
                        radius: 7
                        color: active
                            ? "#1a2a1a"
                            : (wsTabH.containsMouse ? "#13191a" : "transparent")
                        border.color: active ? "#2a6a3a" : "transparent"
                        border.width: 1
                        Behavior on color        { ColorAnimation { duration: 150 } }
                        Behavior on border.color { ColorAnimation { duration: 150 } }

                        Row {
                            anchors.centerIn: parent
                            spacing: 7
                            Text {
                                text: "⬡"
                                color: parent.parent.active ? "#44cc77" : (wsTabH.containsMouse ? "#2a5a3a" : "#2a3a2a")
                                font.pixelSize: 12
                                anchors.verticalCenter: parent.verticalCenter
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }
                            Text {
                                id: wsTabLabel
                                text: "WORKSHOP"
                                color: parent.parent.active ? "#44cc77" : (wsTabH.containsMouse ? "#2a5a3a" : "#2a3a2a")
                                font.pixelSize: 10
                                font.family: "monospace"
                                font.letterSpacing: 1.8
                                font.weight: Font.Bold
                                anchors.verticalCenter: parent.verticalCenter
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }
                        }

                        HoverHandler { id: wsTabH }
                        TapHandler { onTapped: root.activeTab = 1 }
                    }
                }

                // Vertical divider
                Rectangle {
                    width: 1; height: 24
                    color: "#1e2228"
                    anchors.verticalCenter: parent.verticalCenter
                }

                // ── Library toolbar (search + refresh) — only on tab 0 ────
                SearchBar {
                    id: searchBar
                    Layout.fillWidth: true
                    visible: root.activeTab === 0
                    onTextChanged: wallpaperGrid.filterText = text
                }

                // Workshop search hint — only on tab 1
                Text {
                    visible: root.activeTab === 1
                    Layout.fillWidth: true
                    text: "Browse, search and download wallpapers from the Steam Workshop"
                    color: "#2a3a2a"
                    font.pixelSize: 10
                    font.family: "monospace"
                    font.letterSpacing: 0.4
                    elide: Text.ElideRight
                }

                // Refresh button — only on tab 0
                Rectangle {
                    visible: root.activeTab === 0
                    width: 100; height: 34
                    radius: 6
                    color: refreshHover.containsMouse ? "#1a2a4a" : "#13151a"
                    border.color: refreshHover.containsMouse ? "#1a6aff" : "#22262f"
                    border.width: 1

                    Row {
                        anchors.centerIn: parent
                        spacing: 6

                        Text {
                            text: "⟳"
                            color: refreshHover.containsMouse ? "#4a8aff" : "#555"
                            font.pixelSize: 14
                            anchors.verticalCenter: parent.verticalCenter

                            RotationAnimation on rotation {
                                id: spinAnim
                                running: false
                                from: 0; to: 360
                                duration: 600
                                loops: 1
                            }
                        }

                        Text {
                            text: "REFRESH"
                            color: refreshHover.containsMouse ? "#4a8aff" : "#555"
                            font.pixelSize: 10
                            font.letterSpacing: 1.5
                            font.family: "monospace"
                            font.weight: Font.Bold
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    HoverHandler { id: refreshHover }
                    TapHandler {
                        onTapped: {
                            spinAnim.restart()
                            wallpaperService.scanWallpapers()
                        }
                    }

                    Behavior on color { ColorAnimation { duration: 150 } }
                    Behavior on border.color { ColorAnimation { duration: 150 } }
                }

                // After-download refresh hint on workshop tab
                Rectangle {
                    visible: root.activeTab === 1
                    width: 130; height: 34
                    radius: 6
                    color: postDlH.containsMouse ? "#1a2a4a" : "#13151a"
                    border.color: postDlH.containsMouse ? "#1a6aff" : "#22262f"
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 150 } }
                    Behavior on border.color { ColorAnimation { duration: 150 } }

                    Row {
                        anchors.centerIn: parent
                        spacing: 6
                        Text {
                            text: "⟳"
                            color: postDlH.containsMouse ? "#4a8aff" : "#555"
                            font.pixelSize: 14
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: "REFRESH LIBRARY"
                            color: postDlH.containsMouse ? "#4a8aff" : "#555"
                            font.pixelSize: 9
                            font.letterSpacing: 1.2
                            font.family: "monospace"
                            font.weight: Font.Bold
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    HoverHandler { id: postDlH }
                    TapHandler {
                        onTapped: {
                            wallpaperService.scanWallpapers()
                            root.activeTab = 0
                        }
                    }
                }
            }
        }

        // ── Main Content area ──────────────────────────────────────────────
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            // Tab 0: Library grid
            WallpaperGrid {
                id: wallpaperGrid
                anchors.fill: parent
                visible: root.activeTab === 0
                model: wallpaperService.wallpapers

                onApplyRequested: function(workshopId, wallpaperPath) {
                    wallpaperService.applyWallpaper(workshopId, wallpaperPath)
                }
            }

            // Tab 1: Workshop browser
            WorkshopBrowser {
                anchors.fill: parent
                visible: root.activeTab === 1
                workshopRoot: wallpaperService.workshopRoot
            }
        }
    }

    // ── Initial scan on load ────────────────────────────────────────────
    Component.onCompleted: {
        wallpaperService.scanWallpapers()
    }
}
