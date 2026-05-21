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
    "/usr/bin/linux-wallpaperengine"
    // Steam Workshop content root
    readonly property string workshopRoot:
        "/home/tanishk/.local/share/Steam/steamapps/workshop/content/431960"

    // Wallpaper Engine's own assets folder (shaders, textures used by scene wallpapers).
    // This is inside steamapps/common, NOT the workshop folder.
    // lwe auto-detects this if WE is in a standard Steam path — but being explicit
    // prevents "Cannot find a valid assets folder" errors that silently break scenes.
    readonly property string assetsDir:
        "/home/tanishk/.local/share/Steam/steamapps/common/wallpaper_engine/assets"

    // Your niri output name — run `niri msg outputs` in terminal to find yours.
    // Common values: eDP-1, DP-1, HDMI-A-1
    property string screenOutput: "eDP-1"

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
    // NOTE: lwe is launched with & (background) so this process exits immediately
    // with code 0 once the shell forks it. We treat exit 0 from the shell as success.
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
            if (applyProcess._buffer.indexOf('lwe-missing') !== -1) {
                root.statusMessage = "Error: linux-wallpaperengine not found"
                statusClearTimer.restart()
            } else if (applyProcess._buffer.indexOf('assets-missing') !== -1) {
                root.statusMessage = "Error: WE assets folder not found — check assetsDir path"
                statusClearTimer.restart()
            } else if (code === 0) {
                root.statusMessage = "Wallpaper applied"
                statusClearTimer.restart()
            } else {
                root.statusMessage = "Error (code " + code + "): " + applyProcess._buffer.substring(0, 60)
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
            var wp   = killProcess._requestedWallpaperPath  // full folder path e.g. .../431960/2254899955
            var scr  = root.screenOutput
            var adir = root.assetsDir                       // .../wallpaper_engine/assets
            var lwe  = root.lweBinary

            if (!wp)  wp  = ""
            if (!scr) scr = "eDP-1"

            // Build the lwe command.
            // --assets-dir must point to wallpaper_engine/assets (NOT the workshop folder).
            // --bg accepts the full folder path OR a workshop ID — we use the full path.
            // We redirect stdout/stderr to /tmp/lwe.log so errors are visible for debugging
            // without breaking the backgrounded process exit code.
var flags = "--assets-dir \"" + adir + "\" --screen-root " + scr + " --mpv-hwdec=nvdec --scaling fill --verbose --bg \"" + wp + "\""            // Verify assets dir exists before launching, so we get a clear error message.
          var cmd = "if [ ! -x \"" + lwe + "\" ] && ! command -v linux-wallpaperengine >/dev/null 2>&1; then\n"
        + "  echo 'lwe-missing'; exit 2\n"
        + "fi\n"
        + "if [ ! -d \"" + adir + "\" ]; then\n"
        + "  echo 'assets-missing'; exit 3\n"
        + "fi\n"
        + "if [ -x \"" + lwe + "\" ]; then\n"
        + "  __GL_THREADED_OPTIMIZATIONS=0 __GL_YIELD=USLEEP \"" + lwe + "\" " + flags + " > /tmp/lwe.log 2>&1 &\n"
        + "else\n"
        + "  __GL_THREADED_OPTIMIZATIONS=0 __GL_YIELD=USLEEP linux-wallpaperengine " + flags + " > /tmp/lwe.log 2>&1 &\n"
        + "fi"

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
        if (isApplying) return

        isApplying = true
        statusMessage = "Applying…"
        currentWallpaper = workshopId

        killProcess._buffer = ""
        killProcess._requestedWallpaperPath = wallpaperPath
        // Removed the sleep 1 to make the transition instant
        killProcess.command = ["bash", "-lc", "pkill -f \"[l]inux-wallpaperengine\" 2>/dev/null || true"]
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
