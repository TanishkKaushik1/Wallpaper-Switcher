import QtQuick
pragma Singleton
import Quickshell.Io

// Singleton service that owns lwe settings state.
// Reads/writes ~/.config/niri-rice/Wallpaper-Switcher/lwe_settings.json
// Call buildFlags() to get the full CLI flags string for lwe.
QtObject {
    id: root

    // ── Settings state ────────────────────────────────────────────────────
    property int    volume:       50      // 0–100   → --volume <n>
    property bool   mute:         false   //         → --noaudio
    property string scaling:      "fill"  // fill|fit|stretch|default → --scaling
    property int    fps:          60      // 10–144  → --fps <n>
    property bool   disableMouse: false   //         → --no-mouse-input
    property bool   pauseOnFocus: false   //         → --disable-mouse-input
    property string hwdec:        "nvdec" // nvdec|auto|no → --mpv-hwdec=
    property string screen:       "eDP-1" //         → --screen-root

    // ── Paths ─────────────────────────────────────────────────────────────
    readonly property string settingsFile:
        "/home/tanishk/.config/niri-rice/Wallpaper-Switcher/lwe_settings.json"

    // ── Internal ──────────────────────────────────────────────────────────
    property bool _loaded: false

    // ── Process: load settings from disk ─────────────────────────────────
    property var _loadProcess: Process {
        id: loadProcess
        property string _buffer: ""
        onStarted: _buffer = ""
        stdout: SplitParser {
            onRead: function(line) { loadProcess._buffer += line + "\n" }
        }
        onExited: function(code, _) {
            if (code !== 0 || loadProcess._buffer.trim() === "") {
                // File doesn't exist yet — defaults are already set above
                root._loaded = true
                return
            }
            try {
                var d = JSON.parse(loadProcess._buffer)
                if (d.volume       !== undefined) root.volume       = d.volume
                if (d.mute         !== undefined) root.mute         = d.mute
                if (d.scaling      !== undefined) root.scaling      = d.scaling
                if (d.fps          !== undefined) root.fps          = d.fps
                if (d.disableMouse !== undefined) root.disableMouse = d.disableMouse
                if (d.pauseOnFocus !== undefined) root.pauseOnFocus = d.pauseOnFocus
                if (d.hwdec        !== undefined) root.hwdec        = d.hwdec
                if (d.screen       !== undefined) root.screen       = d.screen
            } catch (e) {
                console.warn("LweSettingsService: failed to parse settings JSON:", e)
            }
            root._loaded = true
        }
    }

    // ── Process: save settings to disk ───────────────────────────────────
    property var _saveProcess: Process {
        id: saveProcess
    }

    // ── Public API ────────────────────────────────────────────────────────

    // Call once at startup (e.g. from shell.qml Component.onCompleted)
    function load() {
        loadProcess.command = ["bash", "-c", "cat \"" + settingsFile + "\" 2>/dev/null"]
        loadProcess.running = true
    }

    // Persist current state to lwe_settings.json
    function save() {
        var obj = {
            volume:       root.volume,
            mute:         root.mute,
            scaling:      root.scaling,
            fps:          root.fps,
            disableMouse: root.disableMouse,
            pauseOnFocus: root.pauseOnFocus,
            hwdec:        root.hwdec,
            screen:       root.screen
        }
        var json = JSON.stringify(obj, null, 2)
        var safe = json.replace(/'/g, "'\\''")
        saveProcess.command = [
            "bash", "-c",
            "mkdir -p \"$(dirname '" + settingsFile + "')\" && " +
            "echo '" + safe + "' > \"" + settingsFile + "\""
        ]
        saveProcess.running = true
    }

    // Returns the full lwe CLI flags string built from current settings.
    // WallpaperService._killProcess.onExited calls this instead of hardcoding flags.
    function buildFlags(assetsDir, wallpaperPath) {
        var flags = ""

        flags += "--assets-dir \"" + assetsDir + "\""
        flags += " --screen-root " + root.screen
        flags += " --mpv-hwdec=" + root.hwdec
        flags += " --scaling " + root.scaling
        flags += " --fps " + root.fps

        if (!root.mute) {
            flags += " --volume " + root.volume
        } else {
            flags += " --noaudio"
        }

        if (root.disableMouse) flags += " --no-mouse-input"
        if (root.pauseOnFocus) flags += " --disable-mouse-input"

        flags += " --verbose"
        flags += " --bg \"" + wallpaperPath + "\""

        return flags
    }
}
