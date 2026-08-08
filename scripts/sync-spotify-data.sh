#!/usr/bin/env bash
# Sync Spotify play data from obsidian-music-garden into this repo.
# Usage: ./scripts/sync-spotify-data.sh [path/to/obsidian-music-garden]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
GARDEN_DIR="${1:-${REPO_ROOT}/../obsidian-music-garden}"
SPOTIFY_DATA="${REPO_ROOT}/data/spotify"
PUBLIC_SOURCE="${GARDEN_DIR}/data/published/v1"
PUBLIC_TARGET="${REPO_ROOT}/data/music_garden/v1"

if [[ -f "${PUBLIC_SOURCE}/manifest.json" ]]; then
  echo "Syncing validated Music Garden public-v1 contract"
  TEMP_ROOT="$(mktemp -d)"
  trap 'rm -rf "${TEMP_ROOT}"' EXIT
  CANDIDATE="${TEMP_ROOT}/candidate"
  STAGED_DATA="${TEMP_ROOT}/data"
  mkdir -p "${CANDIDATE}" "${STAGED_DATA}"
  cp -R "${PUBLIC_SOURCE}/." "${CANDIDATE}/"
  python3 "${SCRIPT_DIR}/validate-music-garden-export.py" "${CANDIDATE}"

  cp -R "${REPO_ROOT}/data/." "${STAGED_DATA}/"
  mkdir -p "${STAGED_DATA}/music_garden"
  rm -rf "${STAGED_DATA}/music_garden/v1"
  cp -R "${CANDIDATE}" "${STAGED_DATA}/music_garden/v1"
  HUGO_DATADIR="${STAGED_DATA}" hugo --gc --minify --environment production --destination "${TEMP_ROOT}/public"
  python3 "${SCRIPT_DIR}/check-music-atlas-build.py" "${CANDIDATE}" "${TEMP_ROOT}/public"

  mkdir -p "$(dirname "${PUBLIC_TARGET}")"
  BACKUP="${TEMP_ROOT}/previous"
  if [[ -d "${PUBLIC_TARGET}" ]]; then
    mv "${PUBLIC_TARGET}" "${BACKUP}"
  fi
  if ! mv "${CANDIDATE}" "${PUBLIC_TARGET}"; then
    [[ -d "${BACKUP}" ]] && mv "${BACKUP}" "${PUBLIC_TARGET}"
    exit 1
  fi
  echo "Installed validated public-v1 data after a successful production build."
  exit 0
fi

echo "No public-v1 manifest found; retaining the legacy Spotify pipeline."

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
