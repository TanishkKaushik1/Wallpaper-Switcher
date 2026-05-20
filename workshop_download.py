#!/usr/bin/env python3
"""
Workshop download helper for Wallpaper Engine (appid 431960).
Usage: workshop_download.py <workshop_id> <workshop_root>

Outputs:
  already_downloaded   — folder already exists locally
  downloading          — steamcmd download started in background
  opening_steam        — fallback: opened steam:// URL
  error:<msg>
"""
import sys, os, subprocess, shutil

APP_ID        = 431960
STEAM_USER    = "anonymous"   # works for free workshop items; change if needed

def main():
    if len(sys.argv) < 3:
        print("error:missing arguments")
        sys.exit(1)

    wid           = sys.argv[1].strip()
    workshop_root = sys.argv[2].strip()

    if not wid:
        print("error:empty id")
        sys.exit(1)

    # Already downloaded?
    if os.path.isdir(os.path.join(workshop_root, wid)):
        print("already_downloaded")
        sys.exit(0)

    # ── Try steamcmd (silent background download) ──────────────────────────
    steamcmd = shutil.which("steamcmd")
    if steamcmd:
        cmd = [
            steamcmd,
            "+login", STEAM_USER,
            "+workshop_download_item", str(APP_ID), wid,
            "+quit"
        ]
        try:
            proc = subprocess.Popen(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True
            )
            out, _ = proc.communicate(timeout=120)
            if proc.returncode == 0 and os.path.isdir(os.path.join(workshop_root, wid)):
                print("downloading")
                sys.exit(0)
            # steamcmd may put files in its own dir — check common locations
            for base in [
                os.path.expanduser("~/.steam/steam/steamapps/workshop/content/" + str(APP_ID)),
                os.path.expanduser("~/Steam/steamapps/workshop/content/" + str(APP_ID)),
                "/home/" + os.environ.get("USER","") + "/.local/share/Steam/steamapps/workshop/content/" + str(APP_ID),
            ]:
                if os.path.isdir(os.path.join(base, wid)):
                    print("downloading")
                    sys.exit(0)
            # steamcmd ran but item not found yet (may still be downloading)
            if "Success" in out or "workshop_download_item" in out:
                print("downloading")
                sys.exit(0)
        except subprocess.TimeoutExpired:
            proc.kill()
        except Exception:
            pass

    # ── Fallback: open Steam ───────────────────────────────────────────────
    steam_url = f"steam://url/CommunityFilePage/{wid}"
    try:
        result = subprocess.run(["xdg-open", steam_url], capture_output=True, timeout=10)
        if result.returncode == 0:
            print("opening_steam")
            sys.exit(0)
    except Exception:
        pass

    try:
        subprocess.Popen(["steam", steam_url], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        print("opening_steam")
        sys.exit(0)
    except Exception as e:
        print(f"error:{e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
