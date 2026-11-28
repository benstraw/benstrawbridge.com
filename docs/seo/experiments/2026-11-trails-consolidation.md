# SEO experiment: consolidate the legacy hiking tree into /trails/

Issue [#114](https://github.com/benstraw/benstrawbridge.com/issues/114), PR
[#150](https://github.com/benstraw/benstrawbridge.com/pull/150). The baseline
below was taken on **2026-11-28, before merge**. Add the merge date and the
after-numbers at the bottom when the checks come due.

## What changes

| Old URL | After | Why |
| --- | --- | --- |
| `/projects/hiking/westchester-playa-vista-playa-del-rey-hiking-guide/` (hub) | 301 to `/trails/` | competed with `/trails/` for the same queries |
| `…/oberrieder-dog-park/` | 301 to `/trails/pv-tour/` | covered in depth there |
| `…/bluff-trail/` | 301 to new `/trails/bluff-trail/` | its own trail, now with a GPX map and a description |
| `…/ballona-wetlands/` | 301 to new `/trails/ballona-wetlands/` | moved with a GPX |
| `…/del-rey-lagoon/` | 301 to new `/trails/del-rey-lagoon/` | moved with a GPX and a real description |
| `…/ballona-creek-bike-path/` | 301 to new `/trails/ballona-creek-bike-path/` | moved with a GPX |
| `…/jet-pets/` | stays; now says the field is closed | still ranks for "jet pets lax" |
| `/projects/hiking/` | stays; one-line callout to `/trails/` | old section page |
| `/trails/` | retitled "Hiking and Walking Trails in Los Angeles", new description, grouped by area | position 45 with no clicks |

The earlier Bluff Creek 301 (`…/bluff-creek-trail/` to `/trails/bluff-creek-trail/`)
shipped before this experiment and is part of the baseline.

## Cohorts

- **Treated:** `/trails/`, the four moved or new pages, and the legacy URLs above.
- **Guardrails (must not drop):** `/trails/bluff-creek-trail/` and `/trails/pv-tour/`.
  The Oberrieder redirect feeds the PV tour, so it should hold or gain.
- **Control (unchanged):** `strawberry-peak`, `san-gabriel-mount-dissapointment-lowe-markham`,
  `arizona-hotspring-canyon-trail`, `wisdon-tree-and-lake-hollywood`.

## What we expect

- The legacy tree's impressions and clicks move to the matching `/trails/` URLs, and
  the old URLs drop out of the index.
- `/trails/` gets its first clicks and its position improves from about 45.
- Del Rey Lagoon's click rate improves from the 0.09% the issue measured.
- The new Bluff Trail page starts to rank for "bluff trail" queries, which today are
  answered by the Bluff Creek page (see the rank sample).
- Bluff Creek and the PV tour hold or grow.

## Read this before drawing conclusions

**Volume is small.** The best page gets about 16 Search Console clicks in 28 days and
about 42 PostHog pageviews in 30. A swing of a few clicks is noise. Judge on
impressions and position over 90 days, and use clicks only as a sanity check.

**The legacy tree is smaller than the issue said.** The issue quoted 3,976
impressions and 42 clicks (6-month export to 2026-09-08). In the most recent 90 days
the whole legacy tree has 595 impressions and 5 clicks. There is less to recover than
the issue suggested, and part of the decline already happened.

**Confounders:** holiday seasonality, the weekly Spotify sync adding pages, and other
PRs (consulting) merging nearby. Compare against the control pages, not just the
before number.

## Baseline

Source: Search Console data synced into PostHog (project `benstrawbridge.com`, tables
`gsc…_search_analytics_by_page` and `…_by_query_page`), web search only, data through
**2026-11-25**. Position is the impression-weighted daily average. PostHog numbers
are `$pageview`, test accounts excluded (cohort 228879), 2026-10-29 to 2026-11-27
against the 30 days before.

### Search Console: last 28 days (2026-10-29 to 2026-11-25), vs the 28 days before

| Page | Clicks | Impr. | Pos. | Prior clicks | Prior impr. | Prior pos. |
| --- | --- | --- | --- | --- | --- | --- |
| `/trails/bluff-creek-trail/` (guardrail) | 16 | 604 | 5.2 | 12 | 521 | 5.5 |
| `/trails/pv-tour/` (guardrail) | 4 | 397 | 8.7 | 2 | 262 | 8.3 |
| legacy hub | 1 | 112 | 11.7 | 0 | 77 | 8.6 |
| legacy `del-rey-lagoon` | 0 | 38 | 15.5 | 0 | 16 | 9.6 |
| legacy `bluff-trail` | 0 | 31 | 29.9 | 0 | 2 | 51.5 |
| legacy `jet-pets` | 1 | 16 | 9.7 | 0 | 37 | 8.3 |
| `/trails/` | 0 | 6 | 26.7 | 0 | 2 | 70.0 |
| control: `wisdon-tree-and-lake-hollywood` | 0 | 46 | 21.2 | 0 | 65 | 18.8 |
| control: `arizona-hotspring-canyon-trail` | 0 | 7 | 20.4 | 0 | 12 | 38.9 |
| control: `strawberry-peak` | 0 | 4 | 5.0 | 0 | 37 | 11.6 |
| control: `san-gabriel-…` | 0 | 2 | 4.0 | none | none | none |

`ballona-wetlands`, `ballona-creek-bike-path` and `oberrieder-dog-park`: no
impressions in these windows (oberrieder: 2 impressions in 90 days).

### Search Console: last 90 days (2026-08-28 to 2026-11-25)

| Page | Clicks | Impr. | Pos. |
| --- | --- | --- | --- |
| `/trails/bluff-creek-trail/` | 49 | 1,965 | 5.5 |
| `/trails/pv-tour/` | 14 | 1,168 | 8.2 |
| legacy hub | 3 | 339 | 9.5 |
| `/trails/wisdon-tree-and-lake-hollywood/` | 0 | 117 | 19.3 |
| legacy `jet-pets` | 1 | 97 | 8.5 |
| legacy `del-rey-lagoon` | 0 | 89 | 12.8 |
| legacy `bluff-trail` | 1 | 68 | 24.3 |
| `/trails/strawberry-peak/` | 0 | 46 | 10.8 |
| `/trails/` | 0 | 28 | 45.5 |
| `/trails/arizona-hotspring-canyon-trail/` | 0 | 20 | 35.1 |

Legacy tree total (hub, jet-pets, del-rey-lagoon, bluff-trail, oberrieder): 5 clicks,
595 impressions. By clicks, Bluff Creek is the top page, ahead of the PV tour.

### Top queries by page (90 days, at least 8 impressions)

- **Bluff Creek:** "bluff creek trail" (15 clicks, 281 impr., pos 4.7), "bluffs creek trail"
  (124 impr., 4.9), "bluff creek park playa vista" (64, 7.9), "bluff creek trail playa vista"
  (51, 3.8), "bluff trail park" (14 impr., pos 11.7), "bluff creek trail parking"
  (3 clicks, 8 impr., pos 1.6).
- **PV tour:** "playa vista dog park" (81 impr., pos 8.0), "playa vista parks" (52, 7.9),
  "playa vista park" (20, 11.0), "dog park playa vista" (13, 7.9).
- **Legacy Del Rey Lagoon:** "del rey lagoon" (10 impr., pos 11.8), "playa del rey lagoon"
  (8, 11.1). **Legacy Jet Pets:** "jet pets lax" (39 impr., pos 8.3).

### PostHog pageviews (2026-10-29 to 2026-11-27, and the 30 days before)

| Page | Views | Visitors | From Google | Prior 30 days |
| --- | --- | --- | --- | --- |
| `/trails/bluff-creek-trail/` | 42 | 36 | 22 | 37 (18 from Google) |
| `/trails/pv-tour/` | 21 | 17 | 4 | 6 |
| `/trails/` | 13 | 11 | 1 | 34 |
| `/projects/hiking/` | 6 | 6 | 0 | 7 |
| legacy stops and hub, combined | 11 | | 2 | 25 |

### Live rank sample (2026-11-28, Google, English, US, one result page each)

Checked in a real browser, one search at a time, about 20 seconds apart. No CAPTCHA or
block. Only the first results page was checked, and the browser may be personalized.
Positions count organic results on the page, so they are not the same measure as Search
Console's average position.

| Query | Result |
| --- | --- |
| bluff creek trail | `/trails/bluff-creek-trail/`, 7th of 9 |
| bluff creek trail parking | `/trails/bluff-creek-trail/`, 1st of 8 |
| bluff trail playa del rey | `/trails/bluff-creek-trail/`, 6th of 9 (the Bluff Creek page answers a "bluff trail" query; no Bluff Trail page exists yet) |
| playa vista dog park | not on page 1 (8 results) |
| del rey lagoon | not on page 1 (7 results; AllTrails' Del Rey Lagoon Loop is 6th) |
| ballona wetlands trail | not on page 1 (8 results) |

## Checks

Run on the same cohorts, windows and queries, and add the results below.

1. About 2 weeks after merge: redirects resolve, old URLs start dropping out, the new
   pages are indexed (Search Console URL Inspection).
2. About 8 weeks after merge: compare 28 and 90 day windows against this baseline and
   the control pages, then re-run the rank sample.

The merge date is the PostHog deploy annotation (see
[posthog-deploy-tracking](../../runbooks/posthog-deploy-tracking.md)). Rollback
threshold: set before merge, in the PR.

## Results

_Not yet run._
