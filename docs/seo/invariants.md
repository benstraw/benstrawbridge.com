# SEO invariants

Easy to break, expensive to notice. Verify against **built HTML** in `public/`,
not templates — several are decided by fallback chains.

- **Meta descriptions resolve `.Description` → `.Summary` → `params.description`.**
  A root-level `description` in `hugo.toml` is **silently discarded**; only the
  one under `[params]` is read. That fallback must read as a real sentence — it
  was the 19-character `'Dot Com Consulting'` on 1,091 of 3,005 built pages
  until 2026-09.
- **`params.taxonomyDescription` keeps term pages from sharing one description**
  (Ryder v0.5.0+). Without it all ~820 term pages fall through to
  `params.description` (measured: 819 identical descriptions on v0.4.3). Keys are
  the taxonomy's **singular** name; each value needs **exactly one `%s`** — Go
  appends `%!(EXTRA string=…)` to a format with no verb, and that lands in the
  meta tag. `/tags/` itself keeps the site description by design.
- **Generated pages set their own descriptions.** The artist adaptor
  (`content/listening/artists/_content.gotmpl`) sets one explicitly because the
  page body read "1 plays" on artists heard once.
- **`params.titleShort` ("Ben Strawbridge") is the `<title>` suffix.** Precedence:
  per-page `sectionTitle` → `titleShort` → `site.Title` (34 chars, truncated
  nearly every SERP title). Only `listening` and `musical-genres` ("Benstraw's
  Music Brain") and `trails` ("benstrawbridge.com") set a different
  `sectionTitle`. One equal to `titleShort` is redundant.
- **One `<h1>` per page, and it's the page title, never the wordmark.** Ryder
  v0.5.0 made the wordmark a `<span>`; `showHomeTitle = true` renders the home
  title as `<h1>` (unset it and the home page has no heading). Measured: 2,158
  pages with exactly one, 0 with two. Pages with none are Hugo's meta-refresh
  stubs (pagers, `aliases`), `/tanda-light/` (static passthrough) and
  `/projects/pick-a-square-game/grid-basic/` (scratch `grid-basic/baseof.html`).
  Never fix a missing heading by demoting a title to `<h2>`.
- **Taxonomy and term pages are `["HTML", "OGCard"]` — no RSS.** Hugo's default
  added 825 near-empty, unlinked `index.xml` feeds. Re-adding RSS brings all 825
  back.
- **`layouts/robots.txt` exists to emit the `Sitemap:` line.** `enableRobotsTXT`
  alone produces only `User-agent: *`. Keep the directive.
- **`/links/` entries are noindex**, out of the sitemap and have no OG card;
  `/links/` itself is indexed. The `[[cascade]]` that does this is
  `target.kind = "page"`-scoped — an untargeted cascade also noindexed the list
  page on the first attempt.
- **Previews are noindex** (`X-Robots-Tag` added by `cf-build.sh`). Production
  must never get that header.
- **Structured data:** site-wide `Person` (`params.schema.type`); per-page extras
  (trail `TouristTrip`, etc.) in `layouts/partials/head/schema-extra.html`.
  Validate with Google's Rich Results test after changing it.
- **`/llms.txt`** is a home output format (`LLMSTxt`). Keep it in
  `[outputs] home` — outputs aren't inherited from the theme.

## Redirects vs aliases

**Hugo `aliases` are not redirects.** They emit a meta-refresh page, and this
site has proof they don't consolidate ranking: the bluff-creek page was deleted
in `ae0f1ee` so its alias would fire, and five months later Google still
indexed the stub at position **6.26 — above the real page at 6.74** (15 clicks,
814 impressions). Use a real 301 in `static/_redirects` for anything that has
ever ranked. Mechanics: [deployment/cloudflare.md](../deployment/cloudflare.md#redirects).

## Measuring

Search Console exports, and how to compare them honestly, are in
[search-console/README.md](../search-console/README.md). Site-wide counts are in
[operations/site-stats.md](../operations/site-stats.md). Useful audits on a
build:

```bash
# pages sharing the fallback description
grep -rl --include=index.html "$(grep -oP "description = '\K[^']+" config/_default/hugo.toml)" public | wc -l
# pages with zero or multiple h1
for f in $(find public -name index.html); do c=$(grep -o '<h1' "$f" | wc -l); [ "$c" -ne 1 ] && echo "$c $f"; done | sort | uniq -c | head
```
