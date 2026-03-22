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
- **Analytics**: Plausible analytics partial at `layouts/partials/plausible.html`

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
- **Hugo stats**: `hugo_stats.json` is mounted to assets for Tailwind purging

## Notes

- Theme is a git submodule; changes to theme should be made in the upstream repo
- Tailwind config reads from `hugo_stats.json` for content purging
- Site uses Hugo's timeout of 60s for longer builds
- Timezone set to `America/Los_Angeles`
- Minimum Hugo version: 0.121.1 (non-extended)

## TODO (for Claude — pending after PR merge)

### Walking Tour Guide feature — next steps on laptop

The `claude/read-instructions-cP38E` PR added only the infrastructure groundwork:
- `layouts/partials/extend_head.html` — GPX file preload hint
- `layouts/shortcodes/leaflet-gpx.html` — generic GPX polyline renderer
- Theme submodule update enabling the `extend_head` hook

The full Walking Tour Guide feature is defined in a build spec the user has.
**Ask the user to paste or commit the spec before proceeding.** Suggested path:
```
docs/walking-tour-spec.md
```

#### What the spec requires (summary of outstanding work)

**1. Add Leaflet static assets** (spec §8 references these exact filenames):
```bash
static/css/leaflet.1.9.4.css
static/js/leaflet.1.9.4.js
static/js/leaflet-gpx.1.7.0.js
```
Download from the official Leaflet and leaflet-gpx releases.

**2. Create `layouts/shortcodes/tour-map.html`** (spec §8)
Distinct from the existing generic `leaflet-gpx.html` shortcode. Uses Leaflet +
leaflet-gpx plugin. Reads `stops` from page front matter and renders numbered
circle markers linking to stop anchors. Tile provider: Carto Voyager (no API key).

**3. Create `layouts/partials/schema-tour.html`** (spec §9)
JSON-LD `TouristAttraction` schema. Include in `<head>` when `tour: true` in front
matter. Reads `geo`, `title`, `description` from page params.

**4. Add tour content assets** for each tour (spec §12 shows example structure):
```
content/projects/hiking/{tour-slug}/
├── index.md                     ← generated by agent from assets below
├── {tour}.gpx
├── {stop-name}_original.txt     ← one per stop, raw audio transcription
├── {photos}.jpg / .webp         ← optional, matched by slug prefix
└── tour.yaml                    ← optional overrides (title, parking note, etc.)
```

**5. Generate `index.md`** for each tour (spec §6–7)
Run Claude against the asset folder: parse GPX for stop coordinates, rewrite each
`_original.txt` transcription into 100–200 word first-person narrative, emit YAML
front matter with `stops[]` array, embed `{{< tour-map >}}` shortcode, include
parking section, add `<!-- AD SLOT: after-stop-3 -->` comment after stop 3.

**6. Update `extend_head.html`** if needed
The existing partial preloads a single `gpxFile` param. Tour pages may need it
extended to also preload the Leaflet CSS — or that can live in the shortcode directly.
