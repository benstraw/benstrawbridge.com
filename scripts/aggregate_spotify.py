#!/usr/bin/env python3
"""Aggregate Spotify play data from weekly shards into artists.json and weekly shards."""

import json
import os
import re
import sys
import unicodedata
from collections import defaultdict
from datetime import datetime

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.dirname(SCRIPT_DIR)
SPOTIFY_DATA_DIR = os.path.join(REPO_ROOT, "data", "spotify")


def slugify(text):
    """Convert artist name to URL-safe slug matching Hugo's urlize behavior."""
    text = unicodedata.normalize("NFKD", text)
    text = text.encode("ascii", "ignore").decode("ascii")
    text = text.lower()
    text = re.sub(r"[^\w\s-]", "", text)
    text = re.sub(r"[-\s]+", "-", text)
    return text.strip("-")


def iso_week_start(year, week):
    return datetime.fromisocalendar(int(year), int(week), 1).strftime("%Y-%m-%d")


def iso_week_end(year, week):
    return datetime.fromisocalendar(int(year), int(week), 7).strftime("%Y-%m-%d")


def load_genres():
    """Load genre cache keyed by Spotify artist ID, merging genres.json + topArtists.json."""
    result: dict = {}

    # Primary: genres.json (populated by sync pipeline)
    genres_path = os.path.join(SPOTIFY_DATA_DIR, "genres.json")
    if os.path.exists(genres_path):
        with open(genres_path) as f:
            result = json.load(f)

    # Supplement: topArtists.json (historical top-artists data, richer genre coverage)
    top_artists_path = os.path.join(SPOTIFY_DATA_DIR, "topArtists.json")
    if os.path.exists(top_artists_path):
        with open(top_artists_path) as f:
            raw = json.load(f)
        items = raw.get("items", raw) if isinstance(raw, dict) else raw
        for artist in items:
            aid = artist.get("id", "")
            if not aid:
                continue
            genres = artist.get("genres", [])
            if not genres:
                continue
            if aid not in result:
                result[aid] = {
                    "genres": genres,
                    "images": artist.get("images", []),
                }
            elif not result[aid].get("genres"):
                result[aid]["genres"] = genres

    return result


def load_snapshot():
    """Return snapshot data keyed by Spotify artist ID."""
    snapshot_path = os.path.join(SPOTIFY_DATA_DIR, "snapshot-2024-06.json")
    if not os.path.exists(snapshot_path):
        fallback = os.path.join(SPOTIFY_DATA_DIR, "topArtists_first.json")
        if not os.path.exists(fallback):
            return {}
        source = fallback
    else:
        source = snapshot_path

    with open(source) as f:
        data = json.load(f)

    if isinstance(data, dict) and "items" in data:
        result = {}
        for artist in data["items"]:
            result[artist["id"]] = {
                "images": artist.get("images", []),
                "genres": artist.get("genres", []),
            }
        return result
    return data


def aggregate():
    genres = load_genres()
    snapshot = load_snapshot()
    plays_dir = os.path.join(SPOTIFY_DATA_DIR, "plays")

    if not os.path.exists(plays_dir):
        print(f"ERROR: No plays directory found at {plays_dir}", file=sys.stderr)
        sys.exit(1)

    # artist slug → aggregated data
    artists: dict = {}
    # artist slug → {track_key → {name, spotify_url, plays}}
    artist_tracks: dict = defaultdict(dict)
    # "YYYY-WNN" → weekly summary
    weekly_data: dict = {}

    for year_dir in sorted(os.listdir(plays_dir)):
        year_path = os.path.join(plays_dir, year_dir)
        if not os.path.isdir(year_path):
            continue
        for week_file in sorted(os.listdir(year_path)):
            if not week_file.endswith(".json"):
                continue
            week_id = week_file[:-5]
            m = re.match(r"(\d{4})-W(\d{2})", week_id)
            if not m:
                continue
            year_num, week_num = m.group(1), m.group(2)

            week_path = os.path.join(year_path, week_file)
            with open(week_path) as f:
                plays = json.load(f)

            weekly_artist_counts: dict[str, int] = defaultdict(int)
            weekly_track_counts: dict = {}

            for play in plays:
                artist_id = play.get("artist_id", "")
                artist_name = play.get("artist_name", "")
                if not artist_name:
                    continue
                slug = slugify(artist_name)
                play_date = play.get("played_at", "")[:10]

                # Initialise artist entry
                if slug not in artists:
                    genre_info = genres.get(artist_id, {})
                    snap_info = snapshot.get(artist_id, {})
                    entry: dict = {
                        "id": artist_id,
                        "name": artist_name,
                        "spotify_url": play.get("artist_spotify_url", ""),
                        "total_plays": 0,
                        "first_seen": play_date,
                        "last_seen": play_date,
                        # genres: prefer genres.json, fall back to snapshot
                        "genres": genre_info.get("genres", []) or snap_info.get("genres", []),
                    }
                    # Images: prefer snapshot (higher quality), fall back to genres cache
                    images = snap_info.get("images") or genre_info.get("images", [])
                    if images:
                        entry["images"] = images
                    artists[slug] = entry

                a = artists[slug]
                a["total_plays"] += 1
                if play_date and play_date < a["first_seen"]:
                    a["first_seen"] = play_date
                if play_date and play_date > a["last_seen"]:
                    a["last_seen"] = play_date
                # Backfill genres if we got them now (genres.json first, snapshot fallback)
                if not a["genres"]:
                    a["genres"] = (
                        genres.get(artist_id, {}).get("genres", [])
                        or snapshot.get(artist_id, {}).get("genres", [])
                    )

                weekly_artist_counts[slug] += 1

                # Accumulate per-artist track counts
                track_id = play.get("track_id", "")
                if track_id:
                    at = artist_tracks[slug]
                    if track_id not in at:
                        at[track_id] = {
                            "name": play.get("track_name", ""),
                            "album": play.get("album_name", ""),
                            "spotify_url": play.get("track_spotify_url", ""),
                            "plays": 0,
                        }
                    at[track_id]["plays"] += 1

                track_id = play.get("track_id", "")
                track_key = f"{artist_id}:{track_id}"
                if track_key not in weekly_track_counts:
                    weekly_track_counts[track_key] = {
                        "name": play.get("track_name", ""),
                        "artist": artist_name,
                        "artist_slug": slug,
                        "plays": 0,
                    }
                weekly_track_counts[track_key]["plays"] += 1

            date_start = iso_week_start(year_num, week_num)
            dt = datetime.strptime(date_start, "%Y-%m-%d")
            week_title = f"Week of {dt.strftime('%b')} {dt.day}, {dt.year}"

            top_artists_raw = sorted(
                [
                    {"slug": s, "name": artists[s]["name"], "plays": c}
                    for s, c in weekly_artist_counts.items()
                ],
                key=lambda x: -x["plays"],
            )

            # Embed artist images into each top_artists entry so week shards are self-contained
            top_artists = [
                dict(a, images=artists[a["slug"]].get("images", []))
                for a in top_artists_raw
            ]

            top_tracks = sorted(
                list(weekly_track_counts.values()),
                key=lambda x: -x["plays"],
            )

            top_artist_name = top_artists[0]["name"] if top_artists else ""
            top_artist_images = top_artists[0]["images"] if top_artists else []

            # Compute top genres weighted by play count for this week
            genre_plays: dict[str, int] = defaultdict(int)
            for a in top_artists_raw:
                for g in artists[a["slug"]].get("genres", []):
                    genre_plays[g] += a["plays"]
            top_genres = [
                {"name": g, "plays": c}
                for g, c in sorted(genre_plays.items(), key=lambda x: -x[1])[:10]
            ]

            weekly_data[week_id] = {
                "week": week_id,
                "title": week_title,
                "year": int(year_num),
                "week_num": int(week_num),
                "date_start": date_start,
                "date_end": iso_week_end(year_num, week_num),
                "total_plays": len(plays),
                "unique_artists": len(weekly_artist_counts),
                "topArtistName": top_artist_name,
                "topArtistImages": top_artist_images,
                "top_genres": top_genres,
                "top_artists": top_artists,
                "top_tracks": top_tracks,
            }

    # Backfill snapshot artists that never appeared in play shards.
    # They have no play data but carry genre/image metadata worth preserving
    # so the musical-genres taxonomy stays intact.
    snap_path = os.path.join(SPOTIFY_DATA_DIR, "snapshot-2024-06.json")
    if os.path.exists(snap_path):
        with open(snap_path) as f:
            raw_snapshot = json.load(f)
        for item in raw_snapshot.get("items", []):
            snap_genres = item.get("genres", [])
            if not snap_genres:
                continue
            slug = slugify(item["name"])
            if slug not in artists:
                entry: dict = {
                    "id": item["id"],
                    "name": item["name"],
                    "spotify_url": item.get("external_urls", {}).get("spotify", ""),
                    "total_plays": 0,
                    "first_seen": "",
                    "last_seen": "",
                    "genres": snap_genres,
                }
                images = item.get("images", [])
                if images:
                    entry["images"] = images
                artists[slug] = entry

    # Backfill artists from topArtists.json not in play shards (preserves full genre taxonomy).
    top_artists_path = os.path.join(SPOTIFY_DATA_DIR, "topArtists.json")
    if os.path.exists(top_artists_path):
        with open(top_artists_path) as f:
            raw = json.load(f)
        items = raw.get("items", raw) if isinstance(raw, dict) else raw
        for item in items:
            ta_genres = item.get("genres", [])
            if not ta_genres:
                continue
            slug = slugify(item["name"])
            if slug not in artists:
                entry: dict = {
                    "id": item.get("id", ""),
                    "name": item["name"],
                    "spotify_url": item.get("external_urls", {}).get("spotify", ""),
                    "total_plays": 0,
                    "first_seen": "",
                    "last_seen": "",
                    "genres": ta_genres,
                }
                images = item.get("images", [])
                if images:
                    entry["images"] = images
                artists[slug] = entry

    # Attach top tracks to each artist (from play shards, ordered by play count)
    for slug, track_map in artist_tracks.items():
        if slug in artists:
            top = sorted(track_map.values(), key=lambda t: -t["plays"])
            artists[slug]["top_tracks"] = top

    # For artists with no play-shard tracks, fall back to topTracks.json historical data.
    # Build a lookup: artist_id -> list of tracks (in ranked order from the snapshot).
    top_tracks_path = os.path.join(SPOTIFY_DATA_DIR, "topTracks.json")
    if os.path.exists(top_tracks_path):
        with open(top_tracks_path) as f:
            raw = json.load(f)
        tt_items = raw.get("items", raw) if isinstance(raw, dict) else raw
        # Count occurrences per track per artist — duplicates are real repeated plays
        historical_tracks: dict[str, dict] = defaultdict(dict)
        for track in tt_items:
            for a in track.get("artists", []):
                aid = a["id"]
                tid = track["id"]
                if tid not in historical_tracks[aid]:
                    historical_tracks[aid][tid] = {
                        "name": track["name"],
                        "album": track.get("album", {}).get("name", ""),
                        "spotify_url": track.get("external_urls", {}).get("spotify", ""),
                        "plays": 0,
                    }
                historical_tracks[aid][tid]["plays"] += 1
        for slug, artist in artists.items():
            aid = artist.get("id")
            if aid not in historical_tracks:
                continue
            hist = historical_tracks[aid]
            existing = artist.get("top_tracks", [])
            if not existing:
                # No shard data — use full historical list
                artist["top_tracks"] = sorted(hist.values(), key=lambda t: -t["plays"])
            else:
                # Merge: add historical tracks not already captured in shard data
                existing_urls = {t["spotify_url"] for t in existing if t.get("spotify_url")}
                extras = [t for t in hist.values() if t.get("spotify_url") not in existing_urls]
                artist["top_tracks"] = existing + sorted(extras, key=lambda t: -t["plays"])

    # For artists with no play-shard data, derive total_plays from top_tracks count
    for artist in artists.values():
        if artist.get("total_plays", 0) == 0 and artist.get("top_tracks"):
            artist["total_plays"] = sum(t.get("plays", 0) for t in artist["top_tracks"])

    # Write outputs
    artists_path = os.path.join(SPOTIFY_DATA_DIR, "artists.json")
    with open(artists_path, "w") as f:
        json.dump(artists, f, indent=2, ensure_ascii=False)
    print(f"Wrote {len(artists)} artists → {artists_path}")

    # Write per-week shards: data/spotify/weekly/YYYY/YYYY-WNN.json
    weekly_dir = os.path.join(SPOTIFY_DATA_DIR, "weekly")
    for week_id, week_data in weekly_data.items():
        year_str = str(week_data["year"])
        year_dir = os.path.join(weekly_dir, year_str)
        os.makedirs(year_dir, exist_ok=True)
        week_path = os.path.join(year_dir, f"{week_id}.json")
        with open(week_path, "w") as f:
            json.dump(week_data, f, indent=2, ensure_ascii=False)
    print(f"Wrote {len(weekly_data)} weekly shards → {weekly_dir}/")

    # Remove legacy weekly.json if it exists (replaced by shards)
    legacy_weekly = os.path.join(SPOTIFY_DATA_DIR, "weekly.json")
    if os.path.exists(legacy_weekly):
        os.remove(legacy_weekly)
        print(f"Removed legacy {legacy_weekly}")


if __name__ == "__main__":
    aggregate()
