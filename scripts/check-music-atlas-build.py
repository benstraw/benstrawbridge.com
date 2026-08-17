#!/usr/bin/env python3
"""Assert public-v1 entities, routes, redirects, privacy, and CSP in built HTML."""

from __future__ import annotations

import json
import sys
from pathlib import Path


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def main(data_root: Path, public_root: Path) -> None:
    artists = json.loads((data_root / "artists.json").read_text())
    genres = json.loads((data_root / "genres.json").read_text())
    releases = json.loads((data_root / "releases.json").read_text())
    redirects = json.loads((data_root / "redirects.json").read_text())

    for slug, record in artists.items():
        if record["publication"]["indexed"]:
            require((public_root / "listening" / "artists" / slug / "index.html").is_file(), f"missing artist route {slug}")
    for slug, record in genres.items():
        if record["publication"]["indexed"]:
            require((public_root / "musical-genres" / slug / "index.html").is_file(), f"missing genre route {slug}")
    for slug, record in releases.items():
        if record["publication"]["indexed"]:
            require((public_root / "listening" / "releases" / slug / "index.html").is_file(), f"missing release route {slug}")

    require((public_root / "listening" / "releases" / "index.html").is_file(), "missing release index")
    for kind, prefix in (("artists", ("listening", "artists")), ("genres", ("musical-genres",))):
        for old_slug in redirects[kind]:
            require((public_root.joinpath(*prefix) / old_slug / "index.html").is_file(), f"missing {kind} redirect {old_slug}")

    weekly = public_root / "listening" / "weekly"
    require(not any(path.name.startswith("2024-W") for path in weekly.iterdir()), "synthetic 2024 weekly route exists")
    for root in (public_root / "listening", public_root / "musical-genres"):
        for html in root.rglob("*.html"):
            text = html.read_text(encoding="utf-8")
            require("played_at" not in text and "synthetic-legacy" not in text, f"private marker in {html}")

    listening = (public_root / "listening" / "index.html").read_text(encoding="utf-8")
    require("https://i.scdn.co" in listening, "Spotify image host missing from CSP")
    require("https://upload.wikimedia.org" in listening, "Wikimedia image host missing from CSP")
    require("https://coverartarchive.org" in listening, "Cover Art Archive host missing from CSP")
    print("music atlas route, privacy, redirect, and CSP checks passed")


if __name__ == "__main__":
    main(Path(sys.argv[1]), Path(sys.argv[2]))
