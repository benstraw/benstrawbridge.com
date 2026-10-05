# Forked Ryder partials

Six templates in `layouts/` are **deliberate forks** of theme files, not new
site-only templates. A theme bump that changes the upstream versions will not
touch them, so diff each against the submodule on every Ryder bump:

```bash
diff -u themes/ryder/layouts/_default/list.html layouts/_default/list.html
```

| Site override | Forked from | Why |
| --- | --- | --- |
| `layouts/partials/utils/taxonomy-string.html` | `themes/ryder/layouts/partials/utils/taxonomy-string.html` | Footer: order by count, cap per group |
| `layouts/partials/taxonomy-cloud.html` | `themes/ryder/layouts/partials/taxonomy-cloud.html` | Cloud: per-taxonomy count floor, A–Z / Most-used toggle |
| `layouts/partials/card-image.html` | `themes/ryder/layouts/partials/card-category-color.html` | Category card with a lead image |
| `layouts/_default/list.html` | `themes/ryder/layouts/_default/list.html` | Per-page card type in section lists |
| `layouts/_default/home.html` | `themes/ryder/layouts/_default/home.html` | Link filtering, injected modules, two theme bugs |
| `layouts/404.html` | `themes/ryder/layouts/404.html` | PostHog `404` event |

The first two exist because `musical-genres` is built from Spotify data — 512
terms, 243 of them (47%) applying to exactly one artist — and the theme renders
every term. A draft upstream issue is in
[ryder-issue-footer-taxonomy.md](ryder-issue-footer-taxonomy.md).

The long-term fix is upstreaming all of these to Ryder, which retires the forks.
`utils/card-type.html` must go up with `list.html` — the fork calls it.

## Card: `card-image.html`

`card-image.html` is `card-category-color.html` with a lead image spliced in,
and its premise is that the two are interchangeable inside one grid — so a fix
to the shared markup has to land in both or a feed renders two different cards.
This happened: Ryder v0.4.2 sanitized the summary branch in
`card-category-color.html` (arts-link/ryder#86) and the fork kept dumping
`.Summary` as raw HTML.

The guarded bug is worse than cosmetic. `.Summary` is *rendered HTML*; absent
`<!--more-->` and a `summary` key, Hugo truncates it at `summaryLength` (100)
words, and the cut need not land on an element boundary — an unclosed wrapper
re-parents every card that follows it. The fork has a **wider** blast radius
than the theme partial: it is the section-wide `listCardType` on `/projects/`
and a per-page card elsewhere.

`card-trail.html`, `card-weekly.html` and `card-artist.html` also descend from
this card but aren't forks: `card-trail.html` runs its blurb through `plainify`,
and the other two build their own bodies without `.Summary`.

## Footer: `taxonomy-string.html`

The theme applies only a `minCount` floor and ranges the taxonomy **map**, which
is alphabetical and uncapped — ~78 links on every page, "acid jazz" (7 artists)
before "jazz" (97), growing with the library.

The fork orders by page count, applies `minCount` as a floor, then caps at
`maxTerms` on each `[[params.footer.taxonomies]]` entry. Removing `maxTerms`
restores the unbounded list for that group. Currently 34 genres + 20 tags =
**54 links**.

Before retuning the caps:

- **`minCount` decides the eligible pool, not `maxTerms`.** It filters first, so
  a cap above the pool is inert. Measured: `musical-genres` has 512 terms but 67
  with 10+ artists and 55 with 12+; `tags` has 263 but 33 with 5+ uses and 24
  with 6+.
- **Land caps on a clean count boundary** — taking every term at or above a
  count rather than splitting a tie. `.ByCount` tie-breaks alphabetically
  (observed on Hugo 0.164.0, not documented), so a split tie is stable but hides
  some equally-used terms for no visible reason.

  | genres cap | threshold | tags cap | threshold |
  | --- | --- | --- | --- |
  | 48 | 13+ artists | 40 | 4+ uses |
  | 41 | 14+ | 33 | 5+ |
  | 39 | 15+ | 23 | 6+ |
  | **34** ← set | **16+** | **20** ← set | **7+** |
  | 33 | 17+ | 15 | 8+ |
  | 29 | 19+ | 13 | 9+ |
  | 28 | 20+ | 11 | 10+ |
  | 24 | 21+ | 10 | 11+ |
  | 21 | 22+ | 8 | 12+ |

  Gaps are counts absent from the data (nothing has exactly 18 artists).
  These counts drift as the weekly Spotify sync adds artists.
- **Derive this table from built output**, not source. `public/tags/index.html`
  is unfiltered and carries every term with its count. An earlier version
  regex-parsed front matter across mixed TOML/YAML and was off by one to three
  in every row. Genre counts survive that shortcut (1:1 with
  `data/spotify/artists.json`); tags don't.
- **Ordering and bounding matter more than size.** Even at caps that barely
  shrink the list, the fork buys `jazz` leading, and a fixed ceiling as the
  library grows.

## Cloud: `taxonomy-cloud.html`

`params.taxonomyCloud.minCount` is a **per-taxonomy** table; a taxonomy absent
from it, or set to 1, gets the theme's behaviour. Currently
`"musical-genres" = 2` (512 terms → 268 chips). `/tags/` is deliberately not
listed and shows every term.

Dropping a term from the cloud does **not** orphan it: Hugo still builds every
term page, and `layouts/listening-artist/single.html` links every genre an
artist carries.

Taxonomy listings also get an **A–Z / Most used** toggle (`taxonomyCloudSort`
in `assets/js/extended.js`), gated to `Page.Kind == "taxonomy"` so the theme's
`taxonomy-cloud` shortcode (embedded in `content/posts/tag-cloud/`) renders
without it. The reordering is **CSS, not JS**: each chip carries `--oc` (negated
count) and `order: var(--oc)`, inert while the parent is a block; only
`data-sort="count"` makes it a flex row.

- A–Z (including no-JS and the shortcode) renders exactly as before; the toggle
  is `x-cloak`ed so it never appears dead.
- Equal `order` resolves by DOM order (alphabetical), so "Most used" is count
  desc then A–Z with no rank computed.
- Active state uses `aria-pressed` with Tailwind's `aria-pressed:` variant. Don't
  return a class string from JS — Tailwind never sees it.

Preserve:

- **Don't reorder the default view.** Sorting by count in the template turned
  the cloud into a monotonic size ramp. `.ByCount` appears only to find the
  displayed min and max for the font scale.
- **The font scale is computed over surviving terms.** The `+1` on `$max` is
  load-bearing: it keeps `log($max) - log($min)` non-zero when all shown terms
  share a count.

## List: `list.html`

The theme reads `listCardType` **once, outside the range**, so a page's own card
choice was never consulted on a section list and two feeds could disagree about
the same page. The fork calls `utils/card-type.html` inside the range with the
container's `listCardType` as the fallback. `/projects/` (`"-image"`) and
`/trails/` (`"-trail"`) are unchanged; only a page that asks for its own card
gets one. The helper's `Kind == "page"` guard keeps a section `_index.md` from
drawing an item card when a `[cascade]` puts `cardType` on it.

The diff is three lines inside the `range`; reconcile by re-applying that hunk.
`npm run test:list-cards` guards the behaviour.

## Home: `home.html`

Six deltas, all marked `SITE:` in the file's header comment — that comment is
the authoritative list.

| # | Delta | Retirable? |
| --- | --- | --- |
| 1, 2 | `/links` pages with no `link_url` are skipped in feature and feed loops; link pages with one are kept even with no summary | No — `link_url` is site-only |
| 3, 5 | `home-links-module.html` and `home-listening-module.html` injected between bands | Only once Ryder grows an extension point |
| 4 | Card wrapper gated on what actually renders, not `or .Title .Content` | **Theme bug** (empty bordered card when `showHomeTitle` is false). Upstream it |
| 6 | Card partial resolved per page via `utils/card-type.html` | Same fix as `list.html`; goes up with it |

The home title is the page `<h1>`. Don't demote it to avoid clashing with the
wordmark — see [seo/invariants.md](../seo/invariants.md).

## 404: `404.html`

Markup is verbatim; the only delta is a script tag for `assets/js/not-found.js`.
See [analytics/posthog.md](../analytics/posthog.md#404-tracking). On a bump,
re-copy the theme markup and keep the script block.
