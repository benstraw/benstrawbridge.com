#!/usr/bin/env bash
# Sync Spotify play data from obsidian-music-garden into this repo.
# Usage: ./scripts/sync-spotify-data.sh [path/to/obsidian-music-garden]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
GARDEN_DIR="${1:-${REPO_ROOT}/../obsidian-music-garden}"
SPOTIFY_DATA="${REPO_ROOT}/data/spotify"

echo "Syncing Spotify data"
echo "  Garden: ${GARDEN_DIR}"
echo "  Target: ${SPOTIFY_DATA}"

if [[ ! -d "${GARDEN_DIR}/data/plays" ]]; then
  echo "ERROR: obsidian-music-garden not found or missing data/plays at ${GARDEN_DIR}"
  exit 1
fi

mkdir -p "${SPOTIFY_DATA}"

# Sync weekly play shards
echo "Syncing plays/..."
rsync -av --delete "${GARDEN_DIR}/data/plays/" "${SPOTIFY_DATA}/plays/"

# Sync genres cache
echo "Syncing genres.json..."
cp "${GARDEN_DIR}/data/genres.json" "${SPOTIFY_DATA}/genres.json"

# Preserve June 2024 snapshot on first run
if [[ -f "${SPOTIFY_DATA}/topArtists_first.json" && ! -f "${SPOTIFY_DATA}/snapshot-2024-06.json" ]]; then
  echo "Creating snapshot-2024-06.json from topArtists_first.json..."
  cp "${SPOTIFY_DATA}/topArtists_first.json" "${SPOTIFY_DATA}/snapshot-2024-06.json"
fi

# Aggregate into artists.json and weekly.json
echo "Aggregating..."
python3 "${SCRIPT_DIR}/aggregate_spotify.py"

echo "Done. Run 'git add data/spotify && git commit' to save."
