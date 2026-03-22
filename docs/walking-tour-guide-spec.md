# Walking Tour Guide — Build Spec
**benstrawbridge.com / Hugo**
*Template for generating interactive, SEO-optimized walking tour pages from GPX + audio transcriptions + photographs.*

---

## 1. Purpose

This document is the instructions file for generating a new walking tour guide page on benstrawbridge.com. Given a folder of source assets (GPX, transcription text files, and optionally photos), an AI coding agent should be able to produce a complete, publish-ready Hugo content page with an embedded interactive map, per-stop narrative, and structured metadata — with no manual data entry.

The output should:
- Rank for hyperlocal queries ("playa vista walking tour", "bluff creek parking", "oberreider dog park directions")
- Surface well in AI search (GEO) via structured location data and natural-language stop descriptions
- Serve as the foundation for affiliate-ready trail/tour guide pages as the section scales

---

## 2. Input Assets

All source files for a new tour live in `content/trails/{tour-slug}/`. The agent matches files by **slug** — the normalized base filename before the extension.

### 2a. Required

| File | Description |
|------|-------------|
| `*.gpx` | One GPX file for the full tour route. Contains the track (`<trk>`) and optionally named waypoints (`<wpt>`). If waypoints are absent, stops are inferred from transcription slugs matched to the nearest track point. |
| `*_original.txt` | One text file per stop. Filename slug (before `_original.txt`) is the stop identifier. Content is the raw audio transcription — unedited, first-person, conversational. |

### 2b. Optional

| File | Description |
|------|-------------|
| `*.m4a` | Audio recording per stop. Same slug as the corresponding `.txt`. Linked from the stop card if present (no inline player required — just a download/open link). |
| `*.jpg / *.webp` | Photos. Filename slug prefix matched to stop (e.g. `bluff-creek-park-01.jpg` → bluff-creek-park stop). Multiple photos per stop supported. |
| `tour.yaml` | Manual overrides (see Section 5). If absent, all metadata is inferred. |

### 2c. Transcription encoding

The `_original.txt` files from the Garmin/iPhone voice recorder workflow are **UTF-16 encoded**. Read them with Python as:
```python
with open(f, 'rb') as fp:
    text = fp.read().decode('utf-16')
```
Do not use `open(f, 'r')` — it will produce garbage output.

---

## 3. Stop Identification

Stops are identified by normalizing the `_original.txt` filenames:

```
"bluff Creek Park_original.txt"  →  slug: "bluff-creek-park"
"oberreider dog park_original.txt"  →  slug: "oberreider-dog-park"
"PV trail_original.txt"  →  slug: "pv-trail"
```

**Normalization rules:**
1. Strip `_original.txt` suffix
2. Lowercase
3. Replace spaces and underscores with hyphens
4. Remove special characters

Each slug becomes:
- The stop's `id` in the map
- The anchor link (`#bluff-creek-park`) in the page
- The basis for photo matching

---

## 4. GPX Processing

### File size and density

**Check file size before use.** Garmin and GPS devices record at ~1 point/second. A 2–4 hour hike = 4,000–14,000+ raw track points, typically exported as single-line minified XML. leaflet-gpx will silently fail or render a blank map on files this large.

**Target: ~100–150KB, ~800–1,200 track points.** If the raw export exceeds ~200KB, simplify it:

```python
import xml.etree.ElementTree as ET

src = 'input.gpx'
dst = 'output-simplified.gpx'
ns = 'http://www.topografix.com/GPX/1/1'

ET.register_namespace('', ns)
tree = ET.parse(src)
root = tree.getroot()

for trkseg in root.iter(f'{{{ns}}}trkseg'):
    pts = list(trkseg)
    to_remove = [pts[i] for i in range(len(pts)) if i % 5 != 0]
    if pts and pts[-1] in to_remove:
        to_remove.remove(pts[-1])  # always keep last point
    for pt in to_remove:
        trkseg.remove(pt)

tree.write(dst, xml_declaration=True, encoding='UTF-8')
```

Keeping every 5th point reduces to ~20% of original — the trail line stays visually smooth. Increase stride to 8 or 10 if still over 200KB.

**Finding summit/key coordinates:** To find the highest elevation point in a GPX:
```python
import xml.etree.ElementTree as ET
ns = 'http://www.topografix.com/GPX/1/1'
tree = ET.parse('file.gpx')
pts = list(tree.getroot().iter(f'{{{ns}}}trkpt'))
summit = max(pts, key=lambda p: float(p.find(f'{{{ns}}}ele').text))
print(summit.attrib['lat'], summit.attrib['lon'], summit.find(f'{{{ns}}}ele').text)
```

### GPX file location

GPX files live in the Hugo leaf bundle alongside `index.md`:
```
content/trails/{tour-slug}/
├── index.md
└── {filename}.gpx   ← Hugo serves this as a page resource
```

Hugo serves leaf bundle files at the page's URL path. **Do not put GPX files in `static/trails/`** — a `static/trails/` directory shadows the entire content section and prevents the `/trails/` list page from rendering in the dev server.

### Track rendering
Use `L.GPX` (leaflet-gpx) — self-hosted at `static/js/leaflet-gpx.1.7.0.js`. Do not use manual fetch+parse; L.GPX handles everything including async loading and bounds fitting.

**Critical:** Pass the GPX path as a full absolute URL from site root:
```javascript
new L.GPX('/trails/{tour-slug}/{filename}.gpx', { ... })
```
A relative path silently fails — `getBounds()` returns invalid bounds and `fitBounds` throws.

### Waypoint matching
If the GPX contains named `<wpt>` elements:
- Match wpt `<name>` to stop slug (normalize both before comparing)
- Use the wpt's lat/lon as the stop's map marker position

If no waypoints (track-only GPX — common with Garmin exports):
- Use Python to find the nearest track point to each stop's approximate known location
- Script: `python3 -c "import xml.etree.ElementTree as ET, math; ..."` — see Section 13 for full helper

### Tile provider
Use **Carto Voyager** (free, no API key):
```
https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png
```
Attribution: `© OpenStreetMap contributors © CARTO`

### Leaflet CSS conflict with Tailwind prose
The tour map shortcode renders inside Hugo content which is wrapped in Tailwind's `prose` class. Prose resets SVG presentation attributes, which silently hides the Leaflet polyline track. **Always include this scoped CSS override in the shortcode:**

```css
#tour-map path.leaflet-interactive {
  fill: none !important;
  stroke: #2D6A4F !important;
  stroke-width: 3px !important;
  stroke-opacity: 0.85 !important;
}
#tour-map .leaflet-overlay-pane svg {
  overflow: visible;
}
```

Tailwind prose CSS rules beat SVG presentation attributes (lowest specificity). `stroke: inherit` doesn't help — the prose parent has `stroke: none`. Must hardcode with `!important`.

---

## 5. tour.yaml — Optional Overrides

If present, values here take precedence over inferred values. All fields optional.

```yaml
title: "Playa Vista Parks Walking Tour"
subtitle: "A 3-mile loop through PV's best green spaces — plus where to actually park for Bluff Creek"
description: >
  A self-guided walking tour of Playa Vista's parks, green spaces, and hidden gems.
  Includes the local's guide to Bluff Creek Trail parking.
parking_note: >
  The best parking for this tour (and for Bluff Creek) is on Esplanade or in the
  free lot off Bluff Creek Drive across from Annenberg PetSpace.
total_distance_miles: 3.1
difficulty: easy
tags:
  - Playa-Vista
  - Walking-Tour
  - Dog-Friendly
  - Bluff-Creek
stops:
  bluff-creek-park:
    display_name: "Bluff Creek Park"
    order: 3
    lede: "The unofficial parking secret of the Westside."
```

---

## 6. Output: Hugo Content File

Generate a single Hugo markdown content file at:
```
content/trails/{tour-slug}/index.md
```

### Front matter (TOML)

All tour front matter uses TOML (`+++` delimiters), not YAML. This matches the site-wide convention.

```toml
+++
title = "{Tour Title}"
date = YYYY-MM-DD
description = "{150-char SEO description — include trail name, neighborhood, and one hyperlocal hook}"
tour = true
gpx = "{filename}.gpx"
hideAsideBar = true
tourType = "Walking Tour"  # or "Hiking Tour", shown in header label
tags = ["Tag1", "Tag2"]

[geo]
  lat = 00.000000
  lon = -000.000000
  neighborhood = "{neighborhood}"
  city = "{city}"
  state = "CA"

[[stops]]
  id = "stop-slug"         # must match {#anchor} on H3 heading
  name = "Stop Name"
  lat = 00.000000
  lon = -000.000000
  order = 1                # 1-based; order=1 stop gets the amber star marker
  blurb = "Tweet-length summary shown in the map popup."
  [stops.amenities]        # all fields optional, set only true ones
    bathrooms = true
    picnic = true

# ... repeat [[stops]] for each stop
+++
```

### Page structure

```
Lede paragraph (2–3 sentences): neighborhood, vibe, why this walk, parking hook if relevant

<!--more-->   ← REQUIRED: prevents map JS from leaking into list page card summaries

{{< tour-map gpx="{filename}.gpx" >}}

## About This Tour

**Distance:** ~X miles
**Difficulty:** Easy/Moderate/Challenging
**Surface:** Paved/Dirt trail/Mixed
**Dog-friendly:** Yes/No
**Best time:** ...
**Bathrooms:** ...

## Stops

### {Stop Display Name} {#stop-slug}
{narrative — see Section 7}

---

### {Next Stop} {#next-slug}
...

<!-- AD SLOT: after-stop-3 -->   ← insert after third stop, nowhere else

## Where to Park
{Always present. For walking tours use "Where to Park for Bluff Creek Trail" etc. For hikes, describe trailhead parking and any pass requirements.}
```

**Critical:** The `<!--more-->` tag must come before the `{{< tour-map >}}` shortcode. Hugo's auto-summary (100 words) will otherwise extend into the shortcode HTML, injecting Leaflet CSS/JS into list page cards and causing JS conflicts.

---

## 7. Transcription → Narrative Rewrite Rules

The `_original.txt` files are raw audio transcriptions. They must be rewritten into polished, first-person narrative prose for the page. Apply these rules:

1. **Keep the voice** — first person, local knowledge, opinionated. Do not sanitize into generic trail-guide prose.
2. **Lead with place** — first sentence should orient the reader spatially ("You're standing at the east end of Bluff Creek Park, where the path opens up toward the bluffs.")
3. **Inject one concrete local detail** per stop that a non-local wouldn't know (parking, a hidden bench, the dog water fountain, what building you can see from here).
4. **Answer the implicit question** — what is this place, why should I stop here, what do I do here.
5. **Length** — 100–200 words per stop. Short is good.
6. **No filler** — do not use: "nestled", "boasts", "vibrant", "stunning", "don't miss", "hidden gem".
7. **SEO** — naturally include the stop name, neighborhood name, and any well-known nearby landmark once each. Do not stuff.

---

## 8. Map Embed (Hugo Shortcode)

The shortcode already exists at `layouts/shortcodes/tour-map.html`. Do not recreate it. Reference implementation:

```html
{{ $gpx := .Get "gpx" }}
{{ $stops := .Page.Params.stops }}

<link rel="stylesheet" href="/css/leaflet.1.9.4.css" />
<style>
  /* Required: Tailwind prose overrides SVG presentation attributes */
  #tour-map path.leaflet-interactive {
    fill: none !important;
    stroke: #2D6A4F !important;
    stroke-width: 3px !important;
    stroke-opacity: 0.85 !important;
  }
  #tour-map .leaflet-overlay-pane svg { overflow: visible; }
</style>
<div id="tour-map" style="height:480px; width:100%; border-radius:8px; margin:1.5rem 0;"></div>
<script src="/js/leaflet.1.9.4.js"></script>
<script src="/js/leaflet-gpx.1.7.0.js"></script>

<script>
(function() {
  var map = L.map('tour-map');
  L.tileLayer('https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png', {
    attribution: '&copy; OpenStreetMap contributors &copy; CARTO',
    maxZoom: 19
  }).addTo(map);

  new L.GPX('/trails/{tour-slug}/{{ $gpx }}', {
    async: true,
    marker_options: {
      startIconUrl: null, endIconUrl: null,
      shadowUrl: null, wptIconUrls: { '': null }
    },
    polyline_options: { color: '#2D6A4F', weight: 3, opacity: 0.85, lineCap: 'round', lineJoin: 'round' }
  }).on('loaded', function(e) {
    var bounds = e.target.getBounds();
    if (bounds.isValid()) map.fitBounds(bounds, { padding: [40, 40] });
  }).on('error', function() {
    map.setView([{center_lat}, {center_lon}], 14);
  }).addTo(map);

  var stops = JSON.parse({{ $stops | jsonify }});  // jsonify outputs a JS string, not array — JSON.parse required
  stops.forEach(function(stop, i) {
    var icon = L.divIcon({
      className: '',
      html: '<div style="background:#2D6A4F;color:#fff;border-radius:50%;width:28px;height:28px;display:flex;align-items:center;justify-content:center;font-weight:bold;font-size:13px;box-shadow:0 1px 4px rgba(0,0,0,.4)">' + (i + 1) + '</div>',
      iconSize: [28, 28], iconAnchor: [14, 14]
    });
    L.marker([stop.lat, stop.lon], { icon: icon })
      .bindPopup('<strong>' + stop.name + '</strong><br><a href="#' + stop.id + '">Read description &darr;</a>')
      .addTo(map);
  });
})();
</script>
```

Invoke in content as:
```
{{< tour-map gpx="playa-vista-parks-walking-tour.gpx" >}}
```

**Hugo gotchas:**
- No `is:inline` — that's Astro. Hugo shortcode scripts run in order naturally.
- `{{ $stops | jsonify }}` outputs a **JSON string** (quoted), not an array literal. Wrap with `JSON.parse(...)`.
- GPX path must be absolute from site root. Relative paths silently produce empty bounds.

---

## 9. SEO & Structured Data

### Hugo front matter
```yaml
tour: true      # triggers schema-tour.html partial via extend_head.html hook
geo:
  lat: {float}
  lon: {float}
  neighborhood: "{name}"
  city: "{city}"
  state: "CA"
```

### Schema injection
`layouts/partials/extend_head.html` already exists and calls `schema-tour.html` when `tour: true`. No changes needed for new tours — just set the front matter.

### On-page SEO rules
- H1 must contain neighborhood name + "walking tour" or "trail guide"
- First paragraph must answer: what is this, where is it, who is it for
- Parking section must use the exact phrase "where to park for [trail name]" at least once
- Every stop H3 must contain the stop's proper name as it would appear in a Google search

---

## 10. Affiliate / Commercial Readiness

- **Ad slots**: `<!-- AD SLOT: after-stop-3 -->` comment after the third stop. No other placement.
- **Gear callouts**: Each stop can optionally include a `gear` list in `tour.yaml`. Render as inline links only when populated.
- **AllTrails link**: Include in "About This Tour" when available.
- **No thin content**: Every stop must have at least 100 words of original narrative.

---

## 11. Infrastructure Checklist (one-time, already done)

These files exist and do not need to be recreated for new tours:

- [x] `static/js/leaflet.1.9.4.js`
- [x] `static/css/leaflet.1.9.4.css`
- [x] `static/js/leaflet-gpx.1.7.0.js`
- [x] `layouts/shortcodes/tour-map.html`
- [x] `layouts/partials/extend_head.html` (theme hook for schema injection)
- [x] `layouts/partials/schema-tour.html`
- [x] `layouts/trails/single.html`
- [x] `content/trails/_index.md` (nav entry for Trails)

---

## 12. Per-Tour Checklist

For each new tour, the agent needs to produce:

- [ ] GPX file is under ~200KB (simplify if needed — see Section 4)
- [ ] GPX file placed in `content/trails/{tour-slug}/` (leaf bundle, NOT `static/trails/`)
- [ ] `content/trails/{tour-slug}/index.md` with full TOML front matter and narrative
- [ ] `<!--more-->` tag present after lede paragraph, before `{{< tour-map >}}`
- [ ] `tour-map` shortcode `gpx=` param matches exact GPX filename
- [ ] Stop coordinates derived from GPX (waypoints preferred; nearest track point if track-only)
- [ ] Every stop `id` in front matter matches a `{#anchor}` on an H3 heading
- [ ] Stop `order` values sequential from 1; primary/entrance stop is order 1
- [ ] Parking section present
- [ ] `<!-- AD SLOT: after-stop-3 -->` placed after third stop (walking tours)
- [ ] Hugo build clean — `hugo build` with no new warnings

---

## 13. Stop Coordinate Helper (track-only GPX)

When the GPX has no waypoints, use this Python snippet to find the nearest track point to each stop's approximate location:

```python
import xml.etree.ElementTree as ET, math

def dist(lat1, lon1, lat2, lon2):
    R = 3958.8
    dlat, dlon = math.radians(lat2-lat1), math.radians(lon2-lon1)
    a = math.sin(dlat/2)**2 + math.cos(math.radians(lat1))*math.cos(math.radians(lat2))*math.sin(dlon/2)**2
    return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1-a))

tree = ET.parse('tour.gpx')
ns = {'gpx': 'http://www.topografix.com/GPX/1/1'}
trkpts = tree.getroot().findall('.//gpx:trkpt', ns)

stops_approx = [
    ('stop-slug', 'Display Name', approx_lat, approx_lon),
    # ...
]

for slug, name, alat, alon in stops_approx:
    best = min(trkpts, key=lambda p: dist(float(p.attrib['lat']), float(p.attrib['lon']), alat, alon))
    print(f"{slug}: lat={float(best.attrib['lat']):.6f} lon={float(best.attrib['lon']):.6f}")
```

Flag stops where the nearest track point is more than 0.1 miles from the approximate location — these may need manual review.

---

## 14. Example File Layout

```
content/trails/pv-tour/
├── index.md
└── playa-vista-parks-walking-tour.gpx   ← Hugo serves leaf bundle files directly

content/trails/strawberry-peak/
├── index.md
└── strawbpk.gpx                         ← simplified from raw Garmin export (~122KB)
```

**Do not create `static/trails/`.** A `static/` directory at the same path as a content section shadows the section, breaking the `/trails/` list page in the dev server.

---

*Last updated: March 2026. Template version 1.1 — updated after PV tour build.*
