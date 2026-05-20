#!/usr/bin/env python3
"""
Workshop download helper for Wallpaper Engine (appid 431960).

Usage:
    workshop_download.py <workshop_id> <workshop_root>

Credentials are loaded automatically from:
    ~/.config/niri-rice/steam_credentials.conf

    File format (key=value, no section header needed):
        STEAM_USER=your_username
        STEAM_PASS=your_password

Streams one status line at a time to stdout (QML reads these via Process.stdout):
    already_downloaded          — folder already exists locally
    progress:<message>          — login / download / install phase
    done:<full_item_path>       — success, item is ready at this path
    error:<message>             — something went wrong
"""

import sys
import os
import subprocess
import shutil
import re
import configparser
import pathlib
import time

APP_ID      = 431960
CREDS_FILE  = pathlib.Path.home() / ".config/niri-rice/steam_credentials.conf"


# ── Credentials ───────────────────────────────────────────────────────────────

def load_credentials() -> tuple[str, str]:
    """
    Priority: CLI args > env vars > credentials file.
    Returns (user, password). Exits with error if neither is found.
    """
    user = os.environ.get("STEAM_USER", "")
    pw   = os.environ.get("STEAM_PASS", "")

    if CREDS_FILE.exists():
        try:
            text = "[creds]\n" + CREDS_FILE.read_text()
            cp = configparser.ConfigParser()
            cp.read_string(text)
            user = user or cp.get("creds", "STEAM_USER", fallback="")
            pw   = pw   or cp.get("creds", "STEAM_PASS", fallback="")
        except Exception as e:
            emit(f"error:Could not read credentials file: {e}")
            sys.exit(1)
    else:
        if not user or not pw:
            emit(
                f"error:No credentials found. Create {CREDS_FILE} with:\n"
                "  STEAM_USER=your_username\n"
                "  STEAM_PASS=your_password"
            )
            sys.exit(1)

    if not user:
        emit("error:STEAM_USER is empty in credentials file")
        sys.exit(1)
    if not pw:
        emit("error:STEAM_PASS is empty in credentials file")
        sys.exit(1)

    return user, pw


# ── Path helpers ──────────────────────────────────────────────────────────────

def candidate_paths(wid: str) -> list[str]:
    home = os.path.expanduser("~")
    user = os.environ.get("USER", "")
    return [
        f"{home}/.local/share/Steam/steamapps/workshop/content/{APP_ID}/{wid}",
        f"{home}/.steam/steam/steamapps/workshop/content/{APP_ID}/{wid}",
        f"{home}/Steam/steamapps/workshop/content/{APP_ID}/{wid}",
        f"/home/{user}/.local/share/Steam/steamapps/workshop/content/{APP_ID}/{wid}",
    ]

def find_item(wid: str) -> str | None:
    for p in candidate_paths(wid):
        if os.path.isdir(p):
            return p
    return None


# ── Output ────────────────────────────────────────────────────────────────────

def emit(msg: str):
    """Write a status line and flush immediately so QML sees it in real time."""
    print(msg, flush=True)


# ── Main ──────────────────────────────────────────────────────────────────────

def main():
    if len(sys.argv) < 3:
        emit("error:usage: workshop_download.py <workshop_id> <workshop_root>")
        sys.exit(1)

    wid           = sys.argv[1].strip()
    workshop_root = sys.argv[2].strip()

    if not wid:
        emit("error:empty workshop id")
        sys.exit(1)

    # ── Already downloaded? ───────────────────────────────────────────────
    existing = find_item(wid) or (
        os.path.join(workshop_root, wid)
        if os.path.isdir(os.path.join(workshop_root, wid))
        else None
    )
    if existing:
        emit("already_downloaded")
        sys.exit(0)

    # ── Load credentials (no anonymous fallback) ──────────────────────────
    # CLI args 3 & 4 override the file (useful for one-off testing)
    if len(sys.argv) >= 5:
        steam_user = sys.argv[3].strip()
        steam_pass = sys.argv[4].strip()
    else:
        steam_user, steam_pass = load_credentials()

    # ── Locate steamcmd ───────────────────────────────────────────────────
    steamcmd = shutil.which("steamcmd")
    if not steamcmd:
        emit("error:steamcmd not found — install with: sudo pacman -S steamcmd")
        sys.exit(1)

    # +force_install_dir tells steamcmd where Steam lives.
    # +app_update is only run ONCE (guarded by a stamp file) to initialise
    # the app manifest — after that it's skipped entirely to avoid hammering
    # Steam servers on every download.
    steam_root  = os.path.expanduser("~/.local/share/Steam")
    stamp_file  = pathlib.Path.home() / ".config/niri-rice/.steamcmd_validated"

    need_validate = not stamp_file.exists()

    base_cmd = [
        steamcmd,
        "+force_install_dir", steam_root,
        "+login", steam_user, steam_pass,
    ]
    if need_validate:
        base_cmd += ["+app_update", str(APP_ID), "validate"]

    cmd = base_cmd + [
        "+workshop_download_item", str(APP_ID), wid,
        "+quit",
    ]

    # ── Run steamcmd and stream progress ──────────────────────────────────
    emit("progress:Connecting to Steam...")
    try:
        proc = subprocess.Popen(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            bufsize=1,
        )
    except Exception as e:
        emit(f"error:could not start steamcmd: {e}")
        sys.exit(1)

    PROGRESS_MAP = [
        (r"Logging in",                         "progress:Logging in to Steam..."),
        (r"Waiting for user info",              "progress:Authenticating..."),
        (r"OK$",                                "progress:Logged in — starting download..."),
        (r"Validating",                         "progress:Validating app..."),
        (r"app_update.*validate",               "progress:Validating app..."),
        (r"fully installed",                    "progress:App ready — fetching workshop item..."),
        (r"Downloading item",                   "progress:Downloading wallpaper..."),
        (r"workshop_download_item.*downloading","progress:Downloading wallpaper..."),
        (r"Downloading update",                 "progress:Downloading update..."),
        (r"Installing",                         "progress:Installing..."),
    ]

    raw_lines = []
    for line in proc.stdout:
        line = line.rstrip()
        if not line:
            continue
        raw_lines.append(line)

        # Percent  e.g. " 23.50 %"
        pct = re.search(r'(\d+(?:\.\d+)?)\s*%', line)
        if pct:
            emit(f"progress:Downloading... {pct.group(1)}%")
            continue

        if re.search(r'Success\. Downloaded', line, re.IGNORECASE):
            emit("progress:Finalising...")
            continue

        if "ERROR" in line.upper():
            emit(f"progress:⚠ {line}")
            continue

        for pattern, msg in PROGRESS_MAP:
            if re.search(pattern, line, re.IGNORECASE):
                emit(msg)
                break

    proc.wait()

    # Write stamp so app_update validate never runs again
    if need_validate and proc.returncode == 0:
        try:
            stamp_file.touch()
        except Exception:
            pass

    # ── Post-run check ────────────────────────────────────────────────────
    item_path = find_item(wid)
    if item_path:
        emit(f"done:{item_path}")
        sys.exit(0)

    # Rare race: steamcmd exited 0 but folder not visible yet
    if proc.returncode == 0:
        time.sleep(2)
        item_path = find_item(wid)
        if item_path:
            emit(f"done:{item_path}")
            sys.exit(0)

    # ── Diagnose failure ──────────────────────────────────────────────────
    full_log = "\n".join(raw_lines)
    if "Invalid Password" in full_log or "Bad Password" in full_log:
        emit("error:Invalid Steam password — check your credentials file")
    elif "RateLimitExceeded" in full_log:
        emit("error:Steam rate limit hit — wait a few minutes and try again")
    elif "no subscription" in full_log.lower():
        emit("error:Account doesn't own Wallpaper Engine — cannot download workshop items")
    elif "Two-factor" in full_log or "Steam Guard" in full_log:
        emit("error:Steam Guard required — run: steamcmd +login YOUR_USER +quit  and enter the code once")
    else:
        last = next((l for l in reversed(raw_lines) if l.strip()), "unknown error")
        emit(f"error:steamcmd failed (exit {proc.returncode}): {last}")
    sys.exit(1)


if __name__ == "__main__":
    main()
