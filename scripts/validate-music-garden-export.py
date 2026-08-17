#!/usr/bin/env python3
"""Validate the privacy-safe Music Garden public-v1 contract using stdlib only."""

from __future__ import annotations

import hashlib
import json
import re
import sys
from pathlib import Path

DATE = re.compile(r"^\d{4}-\d{2}-\d{2}$")
HASH = re.compile(r"^[a-f0-9]{64}$")
WEEK = re.compile(r"^weeks/\d{4}/\d{4}-W\d{2}\.json$")
FORBIDDEN_KEYS = {"played_at", "timestamp", "cache_path", "raw_events", "workflow_state"}


def fail(message: str) -> None:
    raise ValueError(message)


def load_json(path: Path):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        fail(f"cannot read valid JSON from {path}: {exc}")


def walk_private(value, path: str = "$") -> None:
    if isinstance(value, dict):
        for key, child in value.items():
            if key.lower() in FORBIDDEN_KEYS:
                fail(f"private field {key!r} at {path}")
            walk_private(child, f"{path}.{key}")
    elif isinstance(value, list):
        for index, child in enumerate(value):
            walk_private(child, f"{path}[{index}]")
    elif isinstance(value, str):
        lowered = value.lower()
        if "synthetic-legacy" in lowered:
            fail(f"synthetic source marker at {path}")
        if re.search(r"\d{4}-\d{2}-\d{2}t\d{2}:\d{2}:\d{2}", value, re.I):
            fail(f"exact timestamp at {path}")


def validate(root: Path) -> None:
    manifest = load_json(root / "manifest.json")
    if manifest.get("contract") != "music-garden.public":
        fail("unsupported contract name")
    version = str(manifest.get("contract_version", ""))
    if not re.match(r"^1\.\d+\.\d+$", version):
        fail(f"unsupported contract major: {version!r}")
    if manifest.get("privacy") != "derived-only":
        fail("manifest is not derived-only")
    if not HASH.fullmatch(str(manifest.get("dataset_sha256", ""))):
        fail("invalid dataset hash")

    required = {"overview.json", "artists.json", "genres.json", "releases.json", "redirects.json"}
    files = manifest.get("files")
    if not isinstance(files, list):
        fail("manifest files must be an array")
    listed = {entry.get("path") for entry in files if isinstance(entry, dict)}
    if not required.issubset(listed):
        fail(f"missing required files: {sorted(required - listed)}")

    dataset = hashlib.sha256()
    for entry in files:
        relative = entry.get("path", "")
        if not isinstance(relative, str) or relative.startswith("/") or ".." in Path(relative).parts:
            fail(f"unsafe manifest path: {relative!r}")
        expected = entry.get("sha256", "")
        if not HASH.fullmatch(str(expected)):
            fail(f"invalid hash for {relative}")
        data = (root / relative).read_bytes()
        actual = hashlib.sha256(data).hexdigest()
        if actual != expected:
            fail(f"checksum mismatch for {relative}")
        dataset.update(f"{relative}\0{actual}\n".encode())
        decoded = json.loads(data)
        walk_private(decoded)
        if relative.startswith("weeks/") and not WEEK.fullmatch(relative):
            fail(f"invalid weekly shard path: {relative}")
    if dataset.hexdigest() != manifest["dataset_sha256"]:
        fail("dataset checksum mismatch")

    overview = load_json(root / "overview.json")
    for key in ("artist_count", "indexed_artists", "indexed_genres", "listened_releases", "weekly_pages"):
        if not isinstance(overview.get(key), int) or overview[key] < 0:
            fail(f"invalid overview count: {key}")
    if overview.get("published_through") and not DATE.fullmatch(overview["published_through"]):
        fail("published_through must be a date")

    for filename in ("artists.json", "genres.json", "releases.json"):
        entities = load_json(root / filename)
        if not isinstance(entities, dict):
            fail(f"{filename} must be keyed by slug")
        for slug, entity in entities.items():
            if entity.get("slug") != slug or not entity.get("name"):
                fail(f"invalid entity identity in {filename}: {slug}")
            publication = entity.get("publication")
            if not isinstance(publication, dict) or not isinstance(publication.get("indexed"), bool):
                fail(f"missing publication decision in {filename}: {slug}")


if __name__ == "__main__":
    try:
        validate(Path(sys.argv[1] if len(sys.argv) > 1 else "data/music_garden/v1"))
    except (ValueError, OSError, json.JSONDecodeError) as exc:
        print(f"music-garden validation failed: {exc}", file=sys.stderr)
        raise SystemExit(1)
    print("music-garden public-v1 validation passed")
