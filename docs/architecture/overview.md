# Architecture overview

benstrawbridge.com is Ben Strawbridge's consulting home, project notebook, link
garden and music log. It is a fully static site: Hugo renders everything at
build time, Cloudflare serves the files, and the only runtime third party is
PostHog (through a first-party proxy).

## Stack

| Layer | What | Where it's configured |
| --- | --- | --- |
| Generator | Hugo **extended**, `0.164.0` pinned in CI and cloud sessions; floor `0.158.0` | `config/_default/module.toml` (`[hugoVersion]`), `scripts/cf-build.sh`, `.claude/hooks/session-start.sh` |
| Theme | Ryder, git submodule at `themes/ryder`, pinned to tag **`v0.5.0`** | `.gitmodules`, `theme = 'ryder'` in both config environments |
| CSS | Tailwind 3 with Ryder's preset, `@tailwindcss/typography`, PostCSS + autoprefixer | `tailwind.config.js`, `postcss.config.js` |
| JS | Alpine.js **CSP build** (`@alpinejs/csp`) + `@alpinejs/focus`, Font Awesome SVG core, Leaflet 1.9.4 + leaflet-gpx (vendored in `static/`) | `assets/js/extended.js`, theme `assets/js/main.js` |
| Hosting | Cloudflare Worker, static assets only, deployed by Workers Builds from `main` | `wrangler.jsonc` — see [deployment/cloudflare.md](../deployment/cloudflare.md) |
| Analytics | PostHog (US cloud) via `t.benstrawbridge.com` | `config/production/hugo.toml` — see [analytics/posthog.md](../analytics/posthog.md) |
| Search | Google Search Console exports in-repo | [search-console/README.md](../search-console/README.md) |

The Alpine **CSP** build matters every time you write a directive: it cannot
evaluate function calls, member calls, arrow functions or multi-statement
expressions inline, and it fails *silently*. Put logic in a named method on a
registered component (`Alpine.data(...)` in `extended.js`) and pass data through
`data-*` attributes.

## Repository layout

```
archetypes/        hugo new templates: default, links, recipe, trail
assets/            Hugo-mounted assets: images, js/extended.js, js/not-found.js,
                   images/og/generated/ (OG cards + manifest.json)
config/_default/   hugo.toml (site + params), module.toml (mounts, Hugo floor), build.toml (stats, cachebusters)
config/production/ production overrides: PostHog, CSP script-src, highlightGithubStrict
content/           all authored pages and content adaptors (_content.gotmpl)
data/              spotify/ (synced weekly), books/, quotations.json, social.json
docs/              this knowledge base
layouts/           site templates and deliberate theme forks
scripts/           build, OG card, test and sync tooling
static/            _headers, _redirects, vendored Leaflet, og-tests gallery, passthrough pages
themes/ryder/      the theme (submodule — change it upstream, not here)
wrangler.jsonc     Worker config
```

Root-level `LINK_CHECK_REPORT.md`, `LINK_INVENTORY.md`, `LINK_MIGRATION_REPORT.md`,
`check_links.*`, `link_checker_final.sh` and `scripts/migrate_links.py` are
leftovers from the January 2026 `/links/` migration. They describe a structure
that no longer exists; don't treat them as current.

## Configuration

- `config/_default/hugo.toml` — site config and nearly all `[params]`. Heavily
  commented; the comments are authoritative for *why* a value is set.
- `config/production/hugo.toml` — merged on top for the `production`
  environment, which is the default for `hugo` / `hugo build`; `hugo server`
  defaults to `development` and skips it. Holds analytics, the
  `'unsafe-inline'` script-src widening, and `highlightGithubStrict = false`.
- `config/_default/module.toml` — mounts `assets/` and `hugo_stats.json` (into
  `assets/watching/` for cache busting). Anything in `assets/` is one
  `resources.Get` away from being published, which is why exports and raw data
  live in `docs/` or `data/` instead.
- `config/_default/build.toml` — `writeStats` and cachebusters. `hugo_stats.json`
  is gitignored and is **not** a Tailwind content input.
- `[security.funcs] getenv` allows only `^HUGO_`, `^CI$` and `^PUBLIC_POSTHOG_`.
  A template reading any other env var gets nothing.

Other site-wide facts: `timeZone = "America/Los_Angeles"`, `timeout = "60s"`,
`summaryLength = 100`, `pagerSize = 24`, `enableGitInfo = false` (so `lastmod`
comes from front matter, falling back to `date`).

## Output formats

| Kind | Outputs |
| --- | --- |
| home | HTML, RSS, `LLMSTxt` (`/llms.txt`), `OGCard` |
| page, section | HTML, `OGCard` (the `/consulting/` hub adds `LLMSTxt` via its own front matter) |
| taxonomy, term | HTML, `OGCard` — **no RSS**, deliberately ([seo/invariants.md](../seo/invariants.md)) |

`OGCard` renders `<path>/og-card.html`, a `noindex` source document that the OG
pipeline screenshots. It is never linked. See [seo/og-cards.md](../seo/og-cards.md).

## Data flow

```
obsidian-music-garden ──(weekly GH Action)──▶ data/spotify/ ──▶ content adaptors ──▶ /listening/…, /musical-genres/…
data/books/example.json ─────────────────────▶ books adaptor ──▶ /projects/content-adaptors/books/…
content/**.md ──▶ Hugo + Ryder + layouts/ ──▶ public/ ──▶ Workers Builds ──▶ Cloudflare edge
                                                   └──▶ scripts/generate-og.mjs ──▶ assets/images/og/generated/ (committed)
Cloudflare check "Workers Builds: benstrawbridge-com" ──▶ GH Action ──▶ PostHog deploy annotation
```

## Layout overrides

Root `layouts/` overrides the theme. Most directories are **site-only** section
layouts (`books/`, `links/`, `listening*/`, `musical-genres/`, `trails/`,
`everything-everywhere/`, `hike-with-ben/`, `grid-basic/`) and shortcodes
(`tour-map`, `webamp`, `framed-shot`, `float-pic`, `alltrails-referral-link`,
`affiliate-link-builder-form`). Six files are **forks** of theme files and must
be reconciled on every Ryder bump — see [theme/ryder-forks.md](../theme/ryder-forks.md).

Per-page JSON-LD beyond the theme's site-wide `Person` entity lives in
`layouts/partials/head/schema-extra.html` (trail pages emit their own
`TouristTrip` block there).

## Theme work

The theme is upstream code. Change it in
[arts-link/ryder](https://github.com/arts-link/ryder), tag a release, then bump
the submodule:

```bash
cd themes/ryder && git fetch --tags && git checkout vX.Y.Z && cd ../..
git add themes/ryder
```

To test unreleased theme work, check the branch out *inside* `themes/ryder`.
Don't reintroduce a second theme path (there used to be a gitignored
`themes/ryder-dev` symlink; it was removed so every environment builds the same
theme). After a bump, diff the six forks.
