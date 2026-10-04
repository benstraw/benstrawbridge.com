# Open Graph cards

Every authored page gets a generated 1200×630 social card, committed as a JPEG
under `assets/images/og/generated/` and tracked in `manifest.json` there
(1,575 cards as of 2026-10-04). Hugo can't composite images like this, so a
card is a **screenshot of a Hugo-rendered page**.

## Pipeline

1. The `OGCard` output format (`config/_default/hugo.toml`) renders
   `<canonical-path>/og-card.html` for home, pages, sections, taxonomies and
   terms. Templates: `layouts/_default/*.ogcard.html`,
   `layouts/trails/single.ogcard.html`, shared partials in
   `layouts/partials/og-card/`. The file is `noindex` and never linked.
2. `scripts/generate-og.mjs` builds the site, serves `public/` on loopback,
   opens each card in Chromium (Playwright), waits for `window.__ogCardReady`,
   and writes `assets/images/og/generated/<path>.jpg` at JPEG quality 88.
3. Each manifest entry stores a **fingerprint of the rendered card HTML**. A card
   is stale when its fingerprint changes, so editing a title, image or template
   marks exactly the affected cards.
4. At build time `layouts/partials/common-partials/opengraph/get-featured-image.html`
   picks the image for `og:image`, Twitter and schema metadata:
   explicit `og_image` → generated card (when `generated_og_metadata_enabled`,
   always for trail pages) → bundle `*feature*` / `*cover*` / `*thumbnail*` →
   `og_image_default`.

Card source imagery: `og_source_image` wins; otherwise a section home uses its
header background, then featured and content images. Pages with
`og_generate = false` (the `/links/` entries) are skipped.

## Commands

```bash
npm run og:generate                          # render missing or stale cards
npm run og:generate -- --only /posts/slug/   # one page (repeat --only for more)
npm run og:generate -- --section trails      # one section (= npm run og:trails)
npm run og:generate -- --force               # rebuild everything
npm run og:check                             # freshness + integrity, no screenshots
npm run og:test                              # unit tests for og-lib.mjs
npm run og:gallery && npm run og:gallery:check   # /og-tests/ review galleries (after a build)
npm run og:review-preview                    # stage galleries + cards into public/ for review
npm run card:shot -- --url … --out …         # 16:9 screenshot for a cardImage (not OG)
```

`og:check` **warns** rather than fails, and Cloudflare builds don't run it, so a
missing card ships silently as the generic image. Run it before committing
content and fix what it reports. A full run prunes cards whose page no longer
exists; targeted runs (`--only`, `--section`) never prune.

Commit the JPEG and `manifest.json` together with the content change.

## Flags

- `params.generated_og_metadata_enabled = true` — use generated cards in page
  metadata (approved 2026-09-25). Set `false` to restore the older chain
  without deleting cards. Trail cards are used regardless.
- `params.publish_generated_og_assets = true` — publish the JPEGs from `assets/`
  so the `/og-tests/` galleries work even with metadata selection off.

## Trail cards: generate locally

Trail cards draw the GPX track over real map tiles (USGS topo for Hiking Tours,
OpenStreetMap for Walking Tours), mirroring `layouts/shortcodes/tour-map.html`.
**Keep `single.ogcard.html` and `tour-map.html` in sync.**

They can't be generated in a Claude Code cloud session. The tile hosts are in
the environment allowlist and `curl` gets 200, but Chromium's tile requests die
with `ERR_CONNECTION_RESET` through the agent proxy (verified 2026-08-05). The
generator fails loudly — a tile error count or a ready timeout — and writes
nothing. That is correct. **Run trail cards on a real machine.**

The readiness handshake requires `tilesLoaded > 0`. An earlier version keyed off
the GPX alone, so hung tile requests produced a blank-map card and a "success".
Don't weaken that check.

`--stub-tiles` serves a flat 1px tile in place of the map to exercise the
plumbing. It **overwrites committed cards** — discard them afterwards
(`git checkout assets/images/og/generated/`).

The browser: if `npm install` resolves a Playwright whose Chromium build isn't
in the image, the scripts fall back to `/opt/pw-browsers/chromium`. Don't run
`npx playwright install`.

No CSP change is involved: tiles are fetched by the screenshotter, never by a
visitor, and the `og:image` is same-origin.
