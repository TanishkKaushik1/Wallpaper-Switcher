#!/usr/bin/env python3
"""
Steam Workshop search helper for Wallpaper Engine (appid 431960).
Called by WorkshopBrowser.qml via Process.
Usage: workshop_search.py <query> [page]
Prints JSON array of results to stdout.
"""
import sys, json, urllib.request, urllib.parse

APP_ID = 431960
PAGE_SIZE = 20


def search(query, page=1):
    cursor = "*"
    # Steam's IPublishedFileService/QueryFiles endpoint
    params = {
        "key": "",           # no key needed for public workshop browsing
        "query_type": 1,     # relevance search
        "page": page,
        "numperpage": PAGE_SIZE,
        "creator_appid": APP_ID,
        "appid": APP_ID,
        "search_text": query,
        "return_metadata": True,
        "return_previews": True,
        "return_tags": True,
        "return_short_description": True,
        "format": "json",
    }
    url = "https://api.steampowered.com/IPublishedFileService/QueryFiles/v1/?" + urllib.parse.urlencode(params)
    try:
        with urllib.request.urlopen(url, timeout=10) as r:
            data = json.loads(r.read())
    except Exception as e:
        print(json.dumps({"error": str(e)}))
        sys.exit(1)

    files = data.get("response", {}).get("publishedfiledetails", [])
    results = []
    for f in files:
        if f.get("result", 0) != 1:
            continue
        # Pick best preview URL
        preview_url = f.get("preview_url", "")
        if not preview_url:
            # fallback to first preview image
            for p in f.get("previews", []):
                if p.get("preview_type") == 0:
                    preview_url = p.get("url", "")
                    break

        # Detect type from tags
        tags = [t.get("tag", "").lower() for t in f.get("tags", [])]
        wp_type = "unknown"
        for t in tags:
            if t in ("scene", "video", "web"):
                wp_type = t
                break

        results.append({
            "workshopId": f.get("publishedfileid", ""),
            "title": f.get("title", ""),
            "previewUrl": preview_url,
            "wallpaperType": wp_type,
            "subscriptions": f.get("subscriptions", 0),
            "description": f.get("short_description", "")[:120],
        })
    print(json.dumps(results))

if __name__ == "__main__":
    query = sys.argv[1] if len(sys.argv) > 1 else "anime"
    page  = int(sys.argv[2]) if len(sys.argv) > 2 else 1
    search(query, page)
