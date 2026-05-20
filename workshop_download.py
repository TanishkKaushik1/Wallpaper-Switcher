#!/usr/bin/env python3
"""
Check if a workshop item is already downloaded, and if not open Steam to download it.
Usage: workshop_download.py <workshopId> <workshopRoot>
Prints: "already_downloaded <path>" or "opening_steam" or "error <msg>"
"""
import sys, os, subprocess

def main():
    if len(sys.argv) < 3:
        print("error missing args")
        sys.exit(1)

    wid = sys.argv[1]
    root = sys.argv[2]
    path = os.path.join(root, wid)

    if os.path.isdir(path):
        print(f"already_downloaded {path}")
        return

    # Open Steam to download the workshop item
    url = f"steam://url/CommunityFilePage/{wid}"
    try:
        subprocess.Popen(["xdg-open", url])
        print("opening_steam")
    except Exception as e:
        print(f"error {e}")

if __name__ == "__main__":
    main()
