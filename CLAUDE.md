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
- **Theme**: Uses `ryder-dev` theme (git submodule at `themes/ryder`)
- **Theme config**: Set in `config/_default/hugo.toml` as `theme = 'ryder-dev'`
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

The hook downloads Hugo itself, which costs about a minute on a cold container.
Anything the hook installs lands *after* the environment snapshot is taken, so
it is not cached between new sessions. Installing Hugo from the environment's
**setup script** instead puts it in the cached snapshot; the hook detects the
existing binary and skips the download, so the two are safe together.

### Theme resolution differs by environment
- `config/_default` sets `theme = 'ryder-dev'`, a **gitignored** path that is
  normally a local working checkout of the theme.
- `config/production` sets `theme = "ryder"`, the submodule.
- The hook symlinks `themes/ryder-dev` → `ryder` so the development environment
  can resolve a theme at all. Nothing else creates that path.

### Build with `--environment development`
`hugo build` defaults to the production environment, where `postcss.config.js`
enables autoprefixer. Autoprefixer resolves targets through browserslist, which
walks above the repo root looking for config and trips the container's
filesystem boundary (`ERR_ACCESS_DENIED / FileSystemRead`). A `.browserslistrc`
does not fix it — the second lookup, for `browserslist-stats.json`, traverses
regardless. Use `hugo build --environment development` in remote sessions; real
production builds happen on AWS Amplify.

### Build-time remote fetches are blocked
Two call sites use `resources.GetRemote` *while building*. Both fail in a remote
container, and the build dies during content processing before any page renders.

**`gohugo.io`** — `content/projects/content-adaptors/books/_content.gotmpl`.
Not in the default Trusted allowlist. Fixable: set the environment's network
access to **Custom**, add `gohugo.io`, and keep "include default list of common
package managers" checked.

**`api.github.com`** — the theme's `highlight-github` shortcode, used by
`content/posts/recipe-template-for-ryder-theme/index.md`. *Not* an allowlist
problem: the host is already in the Trusted defaults, but all GitHub traffic is
intercepted by a credential proxy that only serves git operations and the
built-in GitHub tools. Direct requests from `curl` or `resources.GetRemote` get
403 regardless of network settings. Expect this shortcode to fail in every cloud
session; it works locally.

This is all separate from `params.csp`, which governs what the *browser* may
load at runtime. A host can be fine for one and blocked for the other.

## Notes

- Theme is a git submodule; changes to theme should be made in the upstream repo
- Tailwind scans the site and theme templates/config directly; dynamically
  assembled share-button classes are covered by the config safelist
- Site uses Hugo's timeout of 60s for longer builds
- Timezone set to `America/Los_Angeles`
- Minimum Hugo version: 0.146.0 extended
- When adding or changing anything that loads from outside the site, inspect the built HTML for the page and verify the CSP covers the actual hosts in use. This includes map tiles, Spotify images, PostHog, Leaflet plugins, embeds, and remote fonts.
