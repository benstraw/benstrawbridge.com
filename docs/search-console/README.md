# Search Console exports

Raw Google Search Console performance exports, kept as the before/after baseline
for SEO work on the site. Committed deliberately: the repo is public, so the
ranking and query data is world-readable, and that is accepted as the cost of
having the evidence live beside the code that caused the change.

**Keep these out of `assets/`.** `config/_default/module.toml` mounts `assets`
into Hugo, so anything there is one stray `resources.Get` away from being
published. These CSVs lived at `assets/benstrawbridge.com-Performance-on-Search-2026-03-29/`
until 2026-09-11 — they were never actually published (Hugo only publishes asset
files a template references), but the exposure was one template edit away.

## What's here

| Directory | Window | Days |
| --- | --- | --- |
| `benstrawbridge.com-Performance-on-Search-2026-03-29/` | 2025-09-29 → 2026-03-28 | 181 |
| `benstrawbridge.com-Performance-on-Search-2026-09-11-6mo/` | 2026-03-09 → 2026-09-08 | 184 |
| `benstrawbridge.com-Performance-on-Search-2026-09-11/` | 2026-06-09 → 2026-09-08 | 92 |

The `-6mo` suffix is ours, not Google's. **The window is an export filter, not a
property of the data**, and GSC does not record it in the filename — only in
`Filters.csv`. The two 2026-09-11 directories are the same property on the same
day at different date ranges, so without the suffix they look like duplicates.
The 6-month cut is the apples-to-apples comparison against the March export; the
3-month cut is the cleaner read on recent trend.

Each directory holds the standard seven files. `Pages.csv` (URL, clicks,
impressions, CTR, position) is the one most analysis runs off; `Chart.csv` is
per-day totals and is how you recover the actual date span.

## Comparing two exports

Totals are only comparable across equal windows — check `Filters.csv` before
differencing anything, or normalise per day using `Chart.csv`'s row count.
Bucketing `Pages.csv` by URL prefix (`/trails/`, `/musical-genres/`,
`/listening/artists/`, `/projects/hiking/`) is what surfaced the findings behind
the 2026-09 SEO pass.
