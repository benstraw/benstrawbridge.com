# Site stats

A dated snapshot, for sizing changes and sanity-checking builds. Numbers drift
every week as the Spotify sync adds artists; re-measure rather than quoting
these after a few months.

## Build — 2026-10-04, Hugo 0.164.0, Ryder v0.5.0, `main` @ `30d39e9`

| Measure | Count |
| --- | --- |
| `index.html` files in `public/` | 3,035 |
| …excluding `/page/N/` pagers | 2,037 |
| `sitemap.xml` URLs | ~1,890 |
| `og-card.html` sources | 1,893 |
| Committed OG cards (`manifest.json`) | 1,575 |
| `public/` size | ~494 MB |
| Authored `.md` files in `content/` | 285 |

Pages by section (leaf pages, pagers excluded):

| Section | Pages |
| --- | --- |
| `/listening/artists/` | 940 |
| `/musical-genres/` terms | 516 |
| `/tags/` terms | 275 |
| `/links/` entries | 135 (noindex) |
| `/projects/` (incl. 12 recipes) | 48 |
| `/listening/weekly/` | 33 |
| `/ingredients/` terms | 31 |
| `/posts/` | 21 |
| `/trails/` | 6 |

So roughly three-quarters of the site is generated from Spotify data; authored
content is a few hundred pages.

Spotify data: 940 artists, 7,354 plays, weeks 2026-W07 → 2026-W39.

### Re-measure

```bash
hugo --gc -d /tmp/pub
find /tmp/pub -name index.html | wc -l
find /tmp/pub -name index.html -not -path '*/page/*' | wc -l
grep -o '<loc>' /tmp/pub/sitemap.xml | wc -l
for d in posts projects links trails listening/artists listening/weekly musical-genres tags; do
  echo "$d $(find /tmp/pub/$d -mindepth 2 -name index.html -not -path '*/page/*' | wc -l)"; done
python3 -c "import json;print(len(json.load(open('assets/images/og/generated/manifest.json'))['cards']))"
```

## Traffic — PostHog, last 30 days to 2026-10-04, test accounts filtered

| KPI | Value |
| --- | --- |
| Visitors | 4,816 |
| Pageviews | 5,130 |
| Sessions | 4,886 |
| Avg session duration | ~13 s |
| Bounce rate | 96.4% |

Top pages by visitors: `/` (112), `/links/` (87), `/tags/` (57),
`/posts/the-towers-i-loved-and-the-day-they-fell/` (48),
`/trails/bluff-creek-trail/` (28), `/posts/` (25), `/trails/` (21),
`/404.html` (21), `/consulting/` (14), `/projects/` (11).

Reading it: traffic is a long tail — the top ten pages are under 10% of
visitors, and nearly every session is a single page from search. Session
quality, not volume, is the thing to move.

Re-measure with the PostHog MCP (`query-web-overview`, `query-web-stats` with
`breakdownBy: "Page"`) or the PostHog web analytics dashboard. See
[analytics/posthog.md](../analytics/posthog.md).

## Search

Search Console exports (clicks, impressions, CTR, position by page and query)
are in [search-console/](../search-console/README.md). Compare only equal
windows.
