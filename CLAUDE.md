# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Personal website built with Hugo static site generator, using the Ryder theme (custom Hugo theme as git submodule), Tailwind CSS for styling, and Alpine.js for interactivity.

## Essential Commands

### Development
```bash
# Start local development server (watches for changes)
hugo server

# Start with drafts visible
hugo server -D

# Build production site (outputs to public/)
hugo build

# Install/update npm dependencies
npm install
```

### Content Management
```bash
# Create new content (uses archetypes)
hugo new content posts/my-post.md
hugo new content projects/recipes/my-recipe.md
hugo new content links/my-link-name.md

# Create new recipe (uses recipe.md archetype)
hugo new content --kind recipe projects/recipes/recipe-name.md
```

**Link ordering convention**: When adding new links to any section (e.g., `/links/the-web/`), always add them to the **top** of the list, not the bottom. This keeps the most recent additions visible first.

### Theme & Submodules
```bash
# Initialize theme submodule (first-time setup)
git submodule update --init --recursive

# Update theme to latest
cd themes/ryder
git pull origin main
cd ../..
git add themes/ryder
```

## Architecture

### Theme Structure
- **Theme**: Uses the Ryder theme (git submodule at `themes/ryder`, pinned to v0.4.1)
- **Theme config**: Set in `config/_default/hugo.toml` as `theme = 'ryder'`, matching production
- **Layout overrides**: Root-level `layouts/` directory overrides theme layouts for custom sections
- **Assets**: Root-level `assets/` directory contains site-specific JS, images, and extended functionality

### Configuration Files
- `config/_default/hugo.toml`: Main site configuration
- `config/production/hugo.toml`: Production-specific overrides
- `config/_default/build.toml`: Build settings
- `config/_default/module.toml`: Hugo modules and mounts configuration

### Content Organization
Content follows Hugo's section-based structure with custom taxonomies:

- **Main sections**: `/posts`, `/projects`, `/links`, `/consulting`
- **Recipe content**: Lives under `/projects/recipes/` with recipe archetype
- **Custom taxonomies**:
  - `ingredients` (for recipes)
  - `musical-genres` (for music content)
  - `tags` and `categories` (standard)
- **Excluded from homepage**: Sections listed in `params.excludedSections` and categories in `params.excludedCategories` won't appear on homepage list

### Section Titles
Content sections use `sectionTitle` cascade parameter in `_index.md` frontmatter to customize the `<title>` tag format. Example:
```toml
[cascade]
  sectionTitle = "Recipes on BenStrawbridge.com"
```

### Styling & Frontend
- **Tailwind CSS**: Configured via `tailwind.config.js` with custom theme extensions
  - Custom fonts: Titillium Web
  - Custom background images for headers
  - Custom breakpoints (max 2xl at 1280px)
- **PostCSS**: Used for Tailwind processing (`postcss.config.js`)
- **Alpine.js**: Included via npm dependencies for interactive components
- **Color tokens** (Ryder v0.4.0+): theme colors resolve through `--ryder-*` CSS
  custom properties, exposed as Tailwind classes by the theme preset —
  `text-ryder-brand-800`, `border-ryder-accent-500`, `bg-ryder-brand-alt-50`.
  Defaults are unchanged from the old literals (`--ryder-brand` is sky-800,
  `--ryder-brand-alt` is lime-800, `--ryder-accent` is rose-500). Repoint them
  with `[params.colors]` in `hugo.toml` using **RGB channel triplets, not hex**
  (`"244 63 94"`) — a hex silently breaks every opacity modifier. Site class
  strings in `[params.twClasses]` are literal and deliberately not tokenized.
- **Dark mode**: Enabled with class-based toggle (`darkMode: 'class'` in Tailwind)

### Custom Features
- **Leaflet integration**: Maps library enabled via `params.loadLeaflet`
- **Amazon Associates**: Affiliate ID configured in `params.amazon_associate_id`
- **Share buttons**: Email and LinkedIn configured in `params.shareButtons.networks`
- **Analytics**: Theme-owned analytics via Ryder partials; site config selects the provider
- **Font Awesome**: Site-specific icons must be added in `assets/js/extended.js` and validated with `npm run test:fa-icons` before pushing
- **CSP-sensitive integrations**: Any new external script, image host, tile host, font host, analytics host, embed, or fetch target must be checked against the rendered `Content-Security-Policy` before pushing. This site breaks easily when outside sources are added without updating `params.csp` or theme CSP logic.

### Layout Customizations
Root-level `layouts/` contains section-specific overrides:
- `books/`: List and single layouts for book content
- `spotify-artist/`: Layouts for music/artist content
- `musical-genres/`: Custom genre taxonomy layout
- `everything-everywhere/`: Custom list layout
- `hike-with-ben/`: Custom baseof for hiking content
- Various partials in `layouts/partials/`

### Forked theme partials — reconcile these on every Ryder bump

One partial is a **deliberate fork** of a theme file, not a new site-only
template. A theme bump that changes the upstream version will not touch it, so
diff it against the submodule when upgrading:

| Site override | Forked from |
| --- | --- |
| `layouts/partials/utils/taxonomy-string.html` | `themes/ryder/layouts/partials/utils/taxonomy-string.html` |

It exists because the theme version applies only a `minCount` floor and then
ranges the taxonomy **map**, which is alphabetical and uncapped. `musical-genres`
is built from Spotify data — 512 terms, 47% of them applying to a single artist —
so the footer carried ~78 links on every page ordered such that "acid jazz" (7
artists) preceded "jazz" (97), growing without bound as the library does.

The fork orders by page count, applies `minCount` as a floor, then caps at
`maxTerms` on each `[[params.footer.taxonomies]]` entry. Removing `maxTerms`
restores the theme's unbounded list for that group.

Three things to know before retuning the caps:

- **`minCount` decides the eligible pool, not `maxTerms`.** It filters first, so
  a cap above the pool is inert. Measured: `musical-genres` has 512 terms but 67
  with 10+ artists and 55 with 12+; `tags` has 263 but 33 with 5+ uses and 24
  with 6+. Raising a cap without lowering `minCount` often changes nothing.
- **Land caps on a clean count boundary.** Hugo does not document how `.ByCount`
  orders terms with equal counts, so a cap that slices a tied group can
  reshuffle the footer between builds. The configured 41 takes both 14-artist
  genres; 33 takes all nine 5-use tags.
- **This is a reordering and bounding change, not a size reduction.** At the
  configured caps the footer carries 74 links against the theme's 78. What it
  buys is useful ordering plus a fixed ceiling — not a shorter footer. If footer
  size is the goal, the caps need to come down.

`/musical-genres/` and `/tags/` use the **theme's** `taxonomy-cloud.html`
unmodified — all terms, alphabetical. A previous attempt to fork it and collapse
the long tail was reverted: sorting the cloud by count replaces the interspersed
big-and-small chips that make a tag cloud legible with a monotonic size ramp.
Leave the cloud alone.

The right long-term fix is upstreaming the footer partial to Ryder, which retires
the fork.

### Asset Management
- **Images**: Stored in `assets/images/` with subdirectories by project/section
- **JavaScript**: `assets/js/extended.js` for custom site functionality
- **Hugo stats**: `hugo_stats.json` is generated and mounted to assets for Hugo
  cache busting, but is gitignored and is no longer a Tailwind content input

## Claude Code on the web (remote sessions)

Run these sessions in the **Ryder / Hugo** cloud environment
(`env_01MrAybFDCw6e1U8bKcqRkWi`), shared by every site on the theme. It carries
the Hugo extended toolchain and the `gohugo.io` network allowlist entry that
build-time content adaptors need. Pick it in the environment selector when
starting a session — the choice decides which container clones the repo, so no
committed setting can make it for you.

A fresh remote container clones this repo with an uninitialized Ryder submodule,
no Hugo binary, and no `node_modules`. `.claude/hooks/session-start.sh` restores
all of it at session start and no-ops on local machines. If a session begins and
`themes/ryder` is empty, the hook did not run — fix that before trusting
anything you read in `layouts/`, because an empty theme makes the site look like
it has a fraction of the templates it really has.

Hugo comes from the **Ryder / Hugo** environment's setup script, which runs
before Claude Code launches and lands in the cached filesystem snapshot, so new
sessions start with the binary already present. The hook checks for it and skips
the download when it finds it. In any other environment the hook installs Hugo
itself, which costs about a minute — correct, but uncached, because anything the
hook writes happens *after* the snapshot is taken.

### Theme resolution
Both `config/_default` and `config/production` set `theme = "ryder"`, the
submodule, so every environment builds against the same pinned theme. There is
no separate development theme path: the site previously pointed `config/_default`
at a gitignored `themes/ryder-dev` symlink so it could build against a local
working checkout, and that indirection has been removed. To test unreleased
theme work, check the branch out inside `themes/ryder` rather than reintroducing
a second theme path.

### Build with `--environment development`
`hugo build` defaults to the production environment, where `postcss.config.js`
enables autoprefixer. Autoprefixer resolves targets through browserslist, which
walks above the repo root looking for config and trips the container's
filesystem boundary (`ERR_ACCESS_DENIED / FileSystemRead`). A `.browserslistrc`
does not fix it — the second lookup, for `browserslist-stats.json`, traverses
regardless. Use `hugo build --environment development` in remote sessions; real
production builds happen on AWS Amplify.

### Build-time remote fetches
Two call sites use `resources.GetRemote` *while building*. Both now degrade to a
local fallback instead of killing the build, but **only outside production** —
see "Fallbacks" below. Read the rest of this section for why the hosts fail;
the fallback keeps a cloud session usable, it does not make the fetches work.

**`gohugo.io`** — `content/projects/content-adaptors/books/_content.gotmpl`.
Not in the default Trusted allowlist, so the **Ryder / Hugo** environment uses
**Custom** network access with `gohugo.io` added and "include default list of
common package managers" left checked. A session in any other environment fails
on this file.

Verify that entry is actually in effect rather than assuming it. On 2026-08-02 a
session in the **Ryder / Hugo** environment — Hugo already installed by the setup
script, so the environment was the right one — still got `CONNECT tunnel failed,
response 403` for `gohugo.io`, and the build died on the books adaptor. Check it
in one command before a build:

```bash
curl -sS -o /dev/null -w '%{http_code}\n' https://gohugo.io/
```

A 403 or a CONNECT failure means the allowlist entry is missing or was not
applied to this session; re-check **Custom** network access in the environment
settings.

**`api.github.com`** — the theme's `highlight-github` shortcode, used by
`content/posts/tag-cloud/index.md`, `content/posts/ingredients-section/index.md`
and `content/posts/recipe-template-for-ryder-theme/index.md`. A build that gets
past one of them fails on the next. *Not* an allowlist
problem: the host is already in the Trusted defaults, but all GitHub traffic is
intercepted by a credential proxy that only serves git operations and the
built-in GitHub tools. Direct requests from `curl` or `resources.GetRemote` get
403 regardless of network settings. Expect this shortcode to fail in every cloud
session; it works locally.

Note that `https://api.github.com/` itself returns **200** — only real API paths
such as `/repos/{owner}/{repo}` return 403. Probing the root is therefore a
misleading health check; it looks green while every request the shortcode
actually makes is blocked.

#### Fallbacks
Neither host can be fixed from inside a cloud session, so both call sites catch
the failure and degrade:

- **Books covers** — `_content.gotmpl` falls back to
  `assets/images/books/placeholder-cover.png` (a flat 400×600 PNG, so
  `.Width`/`.Height` still resolve in `layouts/books/single.html`). Alt text
  becomes "<title> (cover image unavailable)" and the resource carries
  `placeholder = true`.
- **Code samples** — handled by the **theme** as of Ryder v0.3.2: the shortcode
  warns and renders a link to the file on GitHub instead of the highlighted
  source. `params.highlightGithubStrict = true` in `config/production` keeps the
  hard failure on Amplify. The site override that used to do this was deleted
  when the submodule moved to v0.3.2 — do not reintroduce it.

Both wrap the call in `try`. This matters: a blocked host raises a *hard
template error* from `resources.GetRemote` rather than setting `.Err`, so a
plain `{{ with … }}{{ else }}` never catches it. `.Err` on the returned
resource was removed in Hugo 0.141, below this repo's 0.146 floor, so reading
it is always a build-aborting error — `try` is the only way to see either
failure. `$attempt.Err` (the `try` result) is a different thing and is correct.

The books fallback applies only when `hugo.Environment` is not `production`;
the shortcode draws the same distinction through `highlightGithubStrict`.
Amplify builds with open network, so a failed fetch there is real and still
stops the build — verified: the same cover fetch logs `WARN` under
`--environment development` and `ERROR` under `--environment production`.
Failures are always logged, so a degraded local build is never silent.

This is all separate from `params.csp`, which governs what the *browser* may
load at runtime. A host can be fine for one and blocked for the other.

## Trail OG cards

Trail pages under `/trails/` have their own Open Graph image: the page's map
with the GPX track drawn on it, the logo words top-left, and the trail name plus
location bottom-left.

Hugo cannot draw a polyline or stitch tiles, so the card is a **screenshot of a
Hugo-rendered page**, not a build-time composite:

- `[outputFormats.OGCard]` in `config/_default/hugo.toml`, cascaded onto trail
  pages by `outputs` in `content/trails/_index.md`, renders
  `layouts/trails/single.ogcard.html` to `/trails/<slug>/og-card.html`.
- That template mirrors `layouts/shortcodes/tour-map.html` — same local Leaflet,
  same tile source keyed off `tourType` (USGS topo for Hiking Tours, CARTO
  voyager for Walking Tours), same GPX and track colour. **Keep the two in sync.**
- `scripts/generate-trail-og.mjs` (`npm run og:trails`) builds the site, serves
  `public/`, waits on the card's `window.__ogCardReady` handshake, writes
  `content/trails/<slug>/og-cover.jpg`, and sets `og_image = "og-cover.jpg"` in
  that page's front matter — which the theme's `get-featured-image.html` picks
  up ahead of everything else.

The script owns both the image and the front-matter line on purpose.
`get-featured-image.html` calls `errorf` on an `og_image` it cannot resolve, so
the two drifting apart breaks the build for everyone. It writes front matter
only after every card has succeeded, so a partial run cannot leave a page
pointing at an image that is not there. Commit the images and the `index.md`
changes together.

Cards are JPEG at quality 88. They were PNG originally, which for screenshots
of photographic topo tiles ran 0.85–1.4MB each — roughly 5× the JPEG for no
visible difference. Any leftover `og-cover.png` is deleted as its JPEG lands.

### Cloud sessions cannot generate cards — generate them locally

`basemap.nationalmap.gov` and `*.basemaps.cartocdn.com` are in the **Ryder /
Hugo** environment's **Custom** network access list, and `curl` reaches both
with a 200. That is necessary but *not* sufficient: Chromium's tile requests
still die with `ERR_CONNECTION_RESET` through the agent proxy, verified
2026-08-05. The generator launches with `proxy` set (bypassing loopback, or the
card page itself 405s) and still gets nothing.

So the script fails loudly in a cloud session:

```
card never signalled ready within 45s (0 tile(s) loaded, 18 failed)
```

That is the correct outcome and no card is written. **Run `npm run og:trails`
on a real machine.**

The failure used to be much worse. The readiness handshake keyed off the GPX
alone, so when tile requests *hung* — no response, no error — the card was
photographed with a blank map and the run reported success. The template now
requires `tilesLoaded > 0` before signalling ready, which converts a silent
blank card into a timeout. Do not weaken that check.

If the allowlist itself ever needs re-verifying, the wildcard is not optional —
Leaflet's `{s}` rotates across `a.`, `b.` and `c.`, so a bare hostname matches
none of the requests:

```bash
curl -sS -o /dev/null -w '%{http_code}\n' \
  https://basemap.nationalmap.gov/arcgis/rest/services/USGSTopo/MapServer/tile/12/1633/703
```

**The browser is handled already.** `npm install` may resolve a `playwright`
whose expected Chromium build is not the one baked into the image, which fails
with "Executable doesn't exist … run npx playwright install". Do not run that —
it downloads ~170MB per session. `launchChromium` in the script already falls
back to `/opt/pw-browsers/chromium`, a stable symlink to the binary that
sidesteps the version registry.

`--stub-tiles` exists only to exercise the plumbing: it produces a flat colour
where the map should be, *will* overwrite committed cards, and rewrites front
matter — so `git checkout content/trails/` afterwards.

No CSP change is involved: tiles are fetched by the screenshotter at generation
time, never by a visitor, and the `og:image` itself is same-origin.

## Notes

- Theme is a git submodule; changes to theme should be made in the upstream repo
- Tailwind scans the site and theme templates/config directly; dynamically
  assembled share-button classes are covered by the config safelist
- Site uses Hugo's timeout of 60s for longer builds
- Timezone set to `America/Los_Angeles`
- Minimum Hugo version: 0.146.0 extended
- When adding or changing anything that loads from outside the site, inspect the built HTML for the page and verify the CSP covers the actual hosts in use. This includes map tiles, Spotify images, PostHog, Leaflet plugins, embeds, and remote fonts.
