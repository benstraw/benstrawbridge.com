# Spotify data and `/listening/`

The `/listening/` section and the `musical-genres` taxonomy are generated from
Spotify play history. Nobody writes these pages by hand.

## Pipeline

```
Spotify API ──(5×/day)──▶ benstraw/obsidian-music-garden  data/plays/, data/genres.json
                                   │
              .github/workflows/sync-spotify-data.yml  (Mondays 06:00 UTC, or manual)
                                   │  scripts/sync-spotify-data.sh <garden path>
                                   ▼
data/spotify/plays/<year>/<YYYY-Www>.json   rsync --delete of raw weekly shards
data/spotify/genres.json                    copied genre cache, keyed by artist id
        └── scripts/aggregate_spotify.py ──▶ data/spotify/artists.json
                                             data/spotify/weekly/<year>/<YYYY-Www>.json
                                   │
              commit "spotify: sync play data YYYY-MM-DD" by github-actions[bot], pushed to main
                                   ▼
Workers Builds deploys ──▶ content adaptors render the pages
```

The workflow checks out `benstraw/obsidian-music-garden` with the
`GARDEN_REPO_TOKEN` secret, runs the sync with Python 3.11, and commits only if
`data/spotify/` changed. Because it pushes to `main`, every sync is a production
deploy (and gets a PostHog deploy marker).

To run it by hand with a local checkout of the garden beside this repo:

```bash
scripts/sync-spotify-data.sh ../obsidian-music-garden
git add data/spotify && git commit -m "spotify: sync play data $(date -u +%F)"
```

## Data files

| File | What | Written by |
| --- | --- | --- |
| `plays/<year>/*.json` | Raw weekly play shards | sync (rsync) |
| `genres.json` | Genre cache by Spotify artist id | sync (copy) |
| `artists.json` | One record per artist slug: `id`, `name`, `spotify_url`, `total_plays`, `first_seen`, `last_seen`, `genres`, `images`, `top_tracks` | `aggregate_spotify.py` |
| `weekly/<year>/*.json` | Per-week summary: totals, unique artists, top artist and images | `aggregate_spotify.py` |
| `topArtists.json`, `topArtists_first.json`, `topTracks*.json` | Historical top-N API snapshots; the aggregator uses `topArtists.json` to backfill genres | legacy, kept |
| `snapshot-2024-06.json` | Preserved June 2024 baseline (created once from `topArtists_first.json`) | sync, once |

Slugs come from `slugify()` in the aggregator, which mirrors Hugo's `urlize`.
If they ever diverge, artist links break; change both together.

As of 2026-10-04: 940 artists, 7,354 total plays, weekly shards 2026-W07 →
2026-W39.

## Pages

- `content/listening/artists/_content.gotmpl` → one page per artist at
  `/listening/artists/<slug>/`, `type = "listening-artist"`, carrying
  `musical-genres` terms. It sets an explicit meta description (the summary
  would read "1 plays" on single-play artists).
- `/listening/artists/` (`layouts/listening-artist/list.html`) is a pill cloud,
  not a grid: all artists, font size scaled by log(plays), image + name + count.
  DOM is alphabetical; `--oc` (negated plays) reorders by CSS when
  `data-sort="plays"` (default). Artists heard once are hidden by default
  (`data-singles`). Controls: `artistCloud` in `assets/js/extended.js`.
- `content/listening/weekly/_content.gotmpl` → one page per ISO week at
  `/listening/weekly/<YYYY-Www>/`, `type = "listening-weekly"`, with
  `layouts/partials/weeknav.html` for prev/next.
- Layouts: `layouts/listening/`, `listening-artist/`, `listening-weekly/`,
  `musical-genres/`; cards `card-artist.html`, `card-weekly.html`.
- Home: `/listening/` is in `excludedSections`; `home-listening-module.html`
  shows the latest week instead.
- Artist images load from `i.scdn.co` at runtime — that host is in the CSP
  `img-src` ([deployment/csp.md](../deployment/csp.md)).
- Known gap: artist pages have no `date`, so they sort to the bottom of any
  date-ordered feed (TODO at the top of the artists adaptor).

## Genre taxonomy effects

Every new artist can add genre terms. That moves the footer and cloud counts
documented in [theme/ryder-forks.md](../theme/ryder-forks.md) — the caps are
bounded on purpose so the footer can't grow without limit. Re-derive the cap
table from `public/musical-genres/index.html` if you retune it.

The retired `/projects/content-adaptors/spotify/` adaptor 301s to
`/listening/artists/` via `static/_redirects`.

`/fineprint/spotify-data-use-disclosure/` describes this data use; keep it
accurate if the pipeline starts collecting anything new.
