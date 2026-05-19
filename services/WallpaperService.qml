import QtQuick
import Quickshell
import Quickshell.Io

// Singleton service that scans the Steam Workshop folder and
// applies wallpapers via linux-wallpaperengine (lwe).
QtObject {
    id: root

    // ── Public state ────────────────────────────────────────────────────
    property ListModel wallpapers: ListModel {}
    property bool isApplying: false
    property string statusMessage: ""
    property string currentWallpaper: ""

    // ── Paths ────────────────────────────────────────────────────────────
    // Binary for linux-wallpaperengine
    readonly property string lweBinary:
        "/home/tanishk/.config/niri-rice/linux-wallpaperengine/build/output/linux-wallpaperengine"

    // Steam Workshop content root
    readonly property string workshopRoot:
        "/home/tanishk/.local/share/Steam/steamapps/workshop/content/431960"

    // ── Internal ─────────────────────────────────────────────────────────
    property var _pendingIds: []
    property int _scanIndex: 0

    // Process: list workshop IDs
    property var _lsProcess: Process {
        id: lsProcess
        property string _buffer: ""

        onStarted: _buffer = ""

        stdout: SplitParser {
            onRead: function(line) { lsProcess._buffer += line + "\n" }
        }

        onExited: function(code, _) {
            if (code !== 0) {
                root.statusMessage = "Failed to read workshop folder"
                return
            }
            var lines = lsProcess._buffer.trim().split("\n")
            var ids = []
            for (var i = 0; i < lines.length; i++) {
                var id = lines[i].trim()
                if (id !== "") ids.push(id)
            }
            root._pendingIds = ids
            root._scanIndex = 0
            root.wallpapers.clear()
            root._readNextProject()
        }
    }

    // Process: read a single project.json
    property var _catProcess: Process {
        id: catProcess
        property string _buffer: ""
        property string _currentId: ""
        property string _currentPath: ""

        onStarted: {
            _buffer = ""
        }

        stdout: SplitParser {
            onRead: function(line) { catProcess._buffer += line + "\n" }
        }

        onExited: function(code, _) {
            var id   = catProcess._currentId
            var path = catProcess._currentPath

            if (code === 0 && catProcess._buffer.trim() !== "") {
                try {
                    var json = JSON.parse(catProcess._buffer)
                    var title   = json.title   || ("Workshop " + id)
                    var preview = json.preview  || ""
                    var type    = json.type     || "unknown"

                    // Build absolute preview path
                    var previewPath = preview !== ""
                        ? (path + "/" + preview)
                        : ""

                    root.wallpapers.append({
                        workshopId:  id,
                        title:       title,
                        wallpaperType: type,
                        previewPath: previewPath,
                        folderPath:  path
                    })
                } catch (e) {
                    // Malformed project.json – add a placeholder
                    root.wallpapers.append({
                        workshopId:  id,
                        title:       "Workshop " + id,
                        wallpaperType: "unknown",
                        previewPath: "",
                        folderPath:  path
                    })
                }
            }

            root._scanIndex++
            root._readNextProject()
        }
    }

    // Process: apply wallpaper via lwe
    property var _applyProcess: Process {
        id: applyProcess
        property string _buffer: ""

        onStarted: _buffer = ""

        stdout: SplitParser {
            onRead: function(line) { applyProcess._buffer += line }
        }
        stderr: SplitParser {
            onRead: function(line) { applyProcess._buffer += line }
        }

        onExited: function(code, _) {
            root.isApplying = false
            console.log("applyProcess: exited code", code, "output:", applyProcess._buffer)
            if (code === 0) {
                root.statusMessage = "Wallpaper applied"
                statusClearTimer.restart()
            } else if (applyProcess._buffer.indexOf('lwe-missing') !== -1) {
                root.statusMessage = "Error: linux-wallpaperengine missing"
                statusClearTimer.restart()
            } else {
                root.statusMessage = "Error (code " + code + ")"
                statusClearTimer.restart()
            }
        }
    }

    // Process: helper to kill existing lwe instances (runs before applyProcess)
    property var _killProcess: Process {
        id: killProcess
        property string _buffer: ""
        property string _requestedWallpaperPath: ""

        onStarted: _buffer = ""

        stdout: SplitParser { onRead: function(line) { killProcess._buffer += line } }
        stderr: SplitParser { onRead: function(line) { killProcess._buffer += line } }

        onExited: function(code, _) {
            // After kill attempt completes, start the apply process
            var wp = killProcess._requestedWallpaperPath
            if (!wp) wp = ""
            // Prefer local build, fall back to PATH `linux-wallpaperengine`
                var cmd = "if [ -x \"" + lweBinary + "\" ]; then \"" + lweBinary + "\" --bg \"" + wp + "\" >/dev/null 2>&1 &\n"
                    + "elif command -v linux-wallpaperengine >/dev/null 2>&1; then linux-wallpaperengine --bg \"" + wp + "\" >/dev/null 2>&1 &\n"
                    + "else echo 'lwe-missing'; exit 2; fi"
            applyProcess._buffer = ""
            applyProcess.command = ["bash", "-c", cmd]
            applyProcess.running = true
        }
    }

    property Timer _statusClearTimer: Timer {
        id: statusClearTimer
        interval: 4000
        repeat: false
        onTriggered: root.statusMessage = ""
    }

    // ── Public API ────────────────────────────────────────────────────────

    function scanWallpapers() {
        wallpapers.clear()
        statusMessage = "Scanning…"
        lsProcess.command = ["bash", "-c",
            "ls -1 \"" + workshopRoot + "\" 2>/dev/null"
        ]
        lsProcess.running = true
    }

    function applyWallpaper(workshopId, wallpaperPath) {
        console.log("WallpaperService: applyWallpaper called ->", workshopId, wallpaperPath)
        if (isApplying) return

        isApplying = true
        statusMessage = "Applying…"
        currentWallpaper = workshopId

        // Kill any previously running lwe instance first, then start new one.
        // lwe takes the folder path via --bg flag.
        // We run pkill in a separate Process to avoid killing the shell that launches the new instance.
        killProcess._buffer = ""
        killProcess._requestedWallpaperPath = wallpaperPath
        // Use a bracketed pattern so the pkill command doesn't match itself
        killProcess.command = ["bash", "-lc", "pkill -f \"[l]inux-wallpaperengine\" 2>/dev/null || true; sleep 0.3"]
        killProcess.running = true
    }

    // ── Internal helpers ──────────────────────────────────────────────────

    function _readNextProject() {
        if (_scanIndex >= _pendingIds.length) {
            statusMessage = wallpapers.count > 0
                ? wallpapers.count + " wallpapers found"
                : "No wallpapers found"
            statusClearTimer.restart()
            return
        }

        var id   = _pendingIds[_scanIndex]
        var path = workshopRoot + "/" + id

        catProcess._currentId   = id
        catProcess._currentPath = path
        catProcess.command = ["bash", "-c",
            "cat \"" + path + "/project.json\" 2>/dev/null"
        ]
        catProcess.running = true
    }
}
