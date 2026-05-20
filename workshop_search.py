#!/usr/bin/env python3
"""
Steam Workshop search helper for Wallpaper Engine (appid 431960).
Called by WorkshopBrowser.qml via Process.
Usage: workshop_search.py <query> [page]
Prints JSON array of results to stdout.
"""
import sys
import json
import urllib.request
import urllib.parse

APP_ID    = 431960
PAGE_SIZE = 20
API_KEY   = "F31E99BE0C94E26B686BF75EEDD472E3"

def fetch(url):
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req, timeout=10) as r:
        return json.loads(r.read().decode())

def search(query, page=1):
    params = urllib.parse.urlencode({
        "key":             API_KEY,
        "appid":           APP_ID,
        "search_text":     query,
        "query_type":      1,
        "numperpage":      PAGE_SIZE,
        "page":            page,
        "return_previews": True,
        "return_metadata": True,
        "return_tags":     False,
    })
    url  = f"https://api.steampowered.com/IPublishedFileService/QueryFiles/v1/?{params}"
    data = fetch(url)

    files = data.get("response", {}).get("publishedfiledetails", [])
    if not files:
        files = data.get("response", {}).get("files", [])

    results = []
    for f in files:
        fid = str(f.get("publishedfileid", ""))
        if not fid:
            continue
        results.append({
            "id":            fid,
            "title":         f.get("title", f"Wallpaper {fid}"),
            "preview_url":   f.get("preview_url", ""),
            "author":        f.get("creator", ""),
            "subscriptions": f.get("subscriptions", 0),
            "type":          f.get("file_type", ""),
            "url":           f"https://steamcommunity.com/sharedfiles/filedetails/?id={fid}",
        })
    return results

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("[]")
        sys.exit(0)

    query = sys.argv[1]
    page  = int(sys.argv[2]) if len(sys.argv) > 2 else 1

    try:
        print(json.dumps(search(query, page)))
    except Exception as e:
        sys.stderr.write(f"error: {e}\n")
        print("[]")
