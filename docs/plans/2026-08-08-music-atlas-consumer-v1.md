# Music Atlas Consumer v1

**Date:** 2026-08-08
**Status:** Implemented on feature branch; production cutover blocked
**Producer plan:** `obsidian-music-garden/docs/plans/2026-08-08-music-atlas-revival-public-contract-v1.md`
**Contract:** music-garden.public v1.0.0

**Status history:** Planned → In Progress → Implemented on feature branch;
production cutover blocked.

## Goal

Make `benstrawbridge.com` a safe consumer of Music Garden's versioned public
export. The site must never reconstruct canonical entities from internal garden
files or replace its last known-good data with an invalid sync.

## Implementation

- Sync and validate `data/published/v1/` into `data/music_garden/v1/` through a
  temporary directory, including contract-major and checksum validation.
- Prefer v1 data when valid and retain the existing `data/spotify/` path as a
  temporary fallback during two successful weekly cycles.
- Generate artist, genre, release, and weekly pages with Hugo content adapters.
- Preserve existing artist, genre, listening, and weekly routes through aliases
  and redirects supplied by the producer.
- Merge optional authored Markdown from
  `assets/listening-notes/{artists,genres,releases}/{slug}.md`.
- Render source attribution and approved media, retain Spotify link-back and
  branding, and verify all media behavior against production CSP.
- Remove `scripts/aggregate_spotify.py` and legacy synchronized data only after
  the dual-run acceptance period.

## Acceptance

- Invalid or incompatible exports cannot modify committed consumer data.
- A production Hugo build passes using the real v1 export.
- Existing routes work or redirect, synthetic 2024 weeks are absent, and no
  exact play timestamp appears in consumer data or rendered HTML.
- Representative artist, genre, release, weekly, no-image, and authored-note
  pages pass responsive, accessibility, attribution, and CSP checks.

## Implementation Record

### 2026-08-08 implementation

- Added public-v1 contract/version/checksum/privacy validation and a staged Hugo
  production build before atomic data replacement.
- Pushed implementation commit `9732992`; the paired producer implementation is
  `57d243d0`. Opened paired draft PRs:
  [consumer #103](https://github.com/benstraw/benstrawbridge.com/pull/103)
  and [producer #11](https://github.com/benstraw/obsidian-music-garden/pull/11).
- Added v1-first artist, genre, release, and weekly adapters; rich entity
  layouts; canonical redirect pages; optional authored-note merge points; CSP
  coverage; and build assertions for routes, privacy, redirects, and media
  hosts.
- The current real fixture builds 124 artist pages, 45 genre pages, 26 weekly
  pages, and an empty release index. No release currently meets the producer's
  qualifying-session threshold.
- Legacy data and aggregation remain only as a fallback pending two successful
  scheduled v1 syncs.
- Production deployment is blocked by the producer plan's Spotify policy
  review. No cutover or legacy removal should occur until that is resolved.

### Test evidence

- Public-v1 validator passed the real export and unit cases for unsupported
  major version, checksum corruption, and missing required files.
- `hugo --gc --minify --environment production` passed against the real export
  (1101 total site pages; only pre-existing PostHog/raw-HTML warnings).
- Route/privacy/redirect/CSP checks passed for every indexed v1 entity and
  exported redirect, with no synthetic 2024 weekly route.
- `npm run test:fa-icons` passed for 68 referenced icons.
- The complete sync script passed validation, staged-data production build,
  post-build assertions, and atomic installation.
- Desktop artist and 390px mobile genre/weekly/release smoke checks showed no
  horizontal overflow, missing image alt text, empty accessible links, or
  private markers. The site theme's existing logo plus page-title dual-H1
  pattern remains unchanged.

Append commits, PRs, weekly sync evidence, and legacy-removal status without
rewriting the original decisions.
