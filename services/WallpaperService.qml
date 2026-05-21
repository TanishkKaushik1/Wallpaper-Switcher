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
    readonly property string lweBinary:
        "/usr/bin/linux-wallpaperengine"
    readonly property string workshopRoot:
        "/home/tanishk/.local/share/Steam/steamapps/workshop/content/431960"
    readonly property string assetsDir:
        "/home/tanishk/.local/share/Steam/steamapps/common/wallpaper_engine/assets"

    // Last wallpaper is persisted here so the restore service can read it
    readonly property string lastWallpaperFile:
        "/home/tanishk/.config/niri-rice/Wallpaper-Switcher/last_wallpaper.json"

    property string screenOutput: "eDP-1"

    // ── Internal ─────────────────────────────────────────────────────────
    property var _pendingIds: []
    property int _scanIndex: 0

    // ── Process: list workshop IDs ────────────────────────────────────────
    property var _lsProcess: Process {
        id: lsProcess
        property string _buffer: ""
        onStarted: _buffer = ""
        stdout: SplitParser {
            onRead: function(line) { lsProcess._buffer += line + "\n" }
        }
        onExited: function(code, _) {
            if (code !== 0) { root.statusMessage = "Failed to read workshop folder"; return }
            var lines = lsProcess._buffer.trim().split("\n")
            var ids = []
            for (var i = 0; i < lines.length; i++) {
                var id = lines[i].trim()
                if (id !== "") ids.push(id)
            }
            root._pendingIds = ids
            root._scanIndex  = 0
            root.wallpapers.clear()
            root._readNextProject()
        }
    }

    // ── Process: read a single project.json ──────────────────────────────
    property var _catProcess: Process {
        id: catProcess
        property string _buffer: ""
        property string _currentId: ""
        property string _currentPath: ""
        onStarted: { _buffer = "" }
        stdout: SplitParser {
            onRead: function(line) { catProcess._buffer += line + "\n" }
        }
        onExited: function(code, _) {
            var id   = catProcess._currentId
            var path = catProcess._currentPath
            if (code === 0 && catProcess._buffer.trim() !== "") {
                try {
                    var json    = JSON.parse(catProcess._buffer)
                    var title   = json.title   || ("Workshop " + id)
                    var preview = json.preview || ""
                    var type    = json.type    || "unknown"
                    
                    // -- NSFW Checking --
                    var contentrating = json.contentrating || ""
                    var tags = json.tags || []
                    var isNsfw = (contentrating.toLowerCase() === "mature" || contentrating.toLowerCase() === "questionable")
                    
                    if (!isNsfw && Array.isArray(tags)) {
                        for (var j = 0; j < tags.length; j++) {
                            var t = String(tags[j]).toLowerCase()
                            if (t === "mature" || t === "nsfw" || t === "questionable") {
                                isNsfw = true
                                break
                            }
                        }
                    }

                    root.wallpapers.append({
                        workshopId:    id,
                        title:         title,
                        wallpaperType: type,
                        previewPath:   preview !== "" ? (path + "/" + preview) : "",
                        folderPath:    path,
                        isNsfw:        isNsfw
                    })
                } catch (e) {
                    root.wallpapers.append({
                        workshopId: id, title: "Workshop " + id,
                        wallpaperType: "unknown", previewPath: "", folderPath: path, isNsfw: false
                    })
                }
            }
            root._scanIndex++
            root._readNextProject()
        }
    }

    // ── Process: apply wallpaper via lwe ─────────────────────────────────
    property var _applyProcess: Process {
        id: applyProcess
        property string _buffer: ""
        onStarted: _buffer = ""
        stdout: SplitParser { onRead: function(line) { applyProcess._buffer += line } }
        stderr: SplitParser { onRead: function(line) { applyProcess._buffer += line } }
        onExited: function(code, _) {
            root.isApplying = false
            if (applyProcess._buffer.indexOf('lwe-missing') !== -1) {
                root.statusMessage = "Error: linux-wallpaperengine not found"
            } else if (applyProcess._buffer.indexOf('assets-missing') !== -1) {
                root.statusMessage = "Error: WE assets folder not found"
            } else if (code === 0) {
                root.statusMessage = "Wallpaper applied ✓"
            } else {
                root.statusMessage = "Error (" + code + "): " + applyProcess._buffer.substring(0, 60)
            }
            statusClearTimer.restart()
        }
    }

    // ── Process: save last wallpaper to disk ─────────────────────────────
    property var _saveProcess: Process {
        id: saveProcess
    }

    function _saveLastWallpaper(workshopId, wallpaperPath) {
        var json = JSON.stringify({ workshopId: workshopId, wallpaperPath: wallpaperPath })
        // Escape single quotes in path just in case
        var safe = json.replace(/'/g, "'\\''")
        saveProcess.command = ["bash", "-c", "echo '" + safe + "' > \"" + root.lastWallpaperFile + "\""]
        saveProcess.running = true
    }

    // ── Process: kill existing lwe then launch new one ────────────────────
    property var _killProcess: Process {
        id: killProcess
        property string _buffer: ""
        property string _requestedWallpaperPath: ""
        property string _requestedWallpaperId: ""

        onStarted: _buffer = ""
        stdout: SplitParser { onRead: function(line) { killProcess._buffer += line } }
        stderr: SplitParser { onRead: function(line) { killProcess._buffer += line } }

        onExited: function(code, _) {
            var wp   = killProcess._requestedWallpaperPath
            var scr  = root.screenOutput
            var adir = root.assetsDir
            var lwe  = root.lweBinary

            if (!wp)  wp = ""
            if (!scr) scr = "eDP-1"

            var flags = LweSettingsService.buildFlags(adir, wp)

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

            applyProcess._buffer  = ""
            applyProcess.command  = ["bash", "-c", cmd]
            applyProcess.running  = true
        }
    }

    property Timer _statusClearTimer: Timer {
        id: statusClearTimer
        interval: 4000; repeat: false
        onTriggered: root.statusMessage = ""
    }

    // ── Public API ────────────────────────────────────────────────────────

    function scanWallpapers() {
        wallpapers.clear()
        statusMessage = "Scanning…"
        lsProcess.command = ["bash", "-c", "ls -1 \"" + workshopRoot + "\" 2>/dev/null"]
        lsProcess.running = true
    }

    function applyWallpaper(workshopId, wallpaperPath) {
        if (isApplying) return
        isApplying      = true
        statusMessage   = "Applying…"
        currentWallpaper = workshopId

        // ← Save so restore service can re-apply after reboot
        _saveLastWallpaper(workshopId, wallpaperPath)

        killProcess._buffer                  = ""
        killProcess._requestedWallpaperPath  = wallpaperPath
        killProcess._requestedWallpaperId    = workshopId
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
        catProcess.command = ["bash", "-c", "cat \"" + path + "/project.json\" 2>/dev/null"]
        catProcess.running = true
    }
}