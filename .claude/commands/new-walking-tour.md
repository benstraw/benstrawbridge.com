---
description: Interview the user and build a new walking tour page for benstrawbridge.com. Use when asked to create a new trail, walking tour, or map guide.
argument-hint: Optional tour name or location
---

# New Walking Tour

You are helping build a new walking tour page for benstrawbridge.com. This is a Hugo site using the `tour-map` shortcode with Leaflet + leaflet-gpx. Tours live at `content/trails/{slug}/index.md` as Hugo page bundles.

## Step 1: Interview the user

Ask the following questions one group at a time. Do not proceed to building until you have enough to start.

### Required
- What is the name of this tour and what slug should it use? (e.g. `mar-vista-tour`)
- Do you have a GPX file? If so, what is its filename?
- What neighborhood/city is this in? (used for the header label)
- One-sentence description of the tour (shown in the header)

### Optional — ask once as a group
"Do you have any of the following? (share what you have and I'll work with it)"
- A list of stops with coordinates (lat/lon) — or I can estimate from the GPX
- Descriptions or notes for each stop (transcription, voice memo, draft text — anything works)
- Known amenities per stop (bathrooms, sports courts, dog park, kids area, picnic, workout stations, bird watching)
- Parking info
- Approximate center coordinates for the map fallback (or I can derive from GPX bounds)

## Step 2: Build the tour

### File structure
Create `content/trails/{slug}/index.md` as a Hugo leaf bundle. The GPX file should be placed in the same directory.

### Front matter schema

```toml
+++
title = "Tour Name"
date = YYYY-MM-DD
description = "One sentence description."

gpx = "your-filename.gpx"  # must match the filename in the shortcode and the bundle

[geo]
  lat = 00.000000        # fallback map center (used if GPX fails to load)
  lon = -000.000000
  neighborhood = "Neighborhood Name"
  city = "City Name"

# stops are optional — omit entirely if no waypoint data
[[stops]]
  id = "stop-slug"       # must match the {#anchor} on the H3 heading below
  name = "Stop Name"
  lat = 00.000000
  lon = -000.000000
  order = 1              # 1-based, determines sequence for Prev/Next nav
  blurb = "Tweet-length summary shown in the map popup."
  [stops.amenities]      # all fields optional, only set true ones
    bathrooms = true
    picnic = true
    soccer = true
    basketball = true
    baseball = true
    tennis = true
    pickleball = true
    workout = true
    dog_park = true
    kids = true
    birdwatching = true
+++
```

### Content body opening
Always start with a 1–2 sentence intro, then `<!--more-->` to cut the card summary, then the shortcode. This prevents the map JS from leaking into the list page card:
```
One sentence description of the hike or tour.

<!--more-->

{{< tour-map gpx="your-filename.gpx" >}}
```

### Minimum viable page (GPX only, no stops)
If there are no stops yet, the map will still render and draw the trail line. Just omit all `[[stops]]` blocks and leave the content body minimal.

### Content body structure
Follow this section order (all optional except the shortcode):

1. `{{< tour-map gpx="..." >}}` — always first
2. **About This Tour** H2 — specs list (distance, time, difficulty, surface, dogs, strollers)
3. **Where to Park** H2 — parking details
4. **The Stops** H2 — one H3 per stop with `{#stop-slug}` anchor matching the front matter `id`

### Stop heading format
```markdown
### Stop Name {#stop-slug}

Prose description...

---
```

The CSS counter in `layouts/trails/single.html` auto-numbers the H3s — do not add numbers to headings manually.

### Amenity icons reference
| Key | Emoji | Label |
|-----|-------|-------|
| soccer | ⚽ | Soccer |
| basketball | 🏀 | Basketball |
| baseball | ⚾ | Baseball |
| tennis | 🎾 | Tennis |
| pickleball | 🏓 | Pickleball |
| workout | 💪 | Workout Stations |
| bathrooms | 🚻 | Bathrooms |
| picnic | 🧺 | Picnic Areas |
| dog_park | 🐕 | Off-Leash Dog Park |
| kids | 🛝 | Playground |
| birdwatching | 🦅 | Bird Watching |

## GPX File Preparation

**Before using a GPX file, check its size.** Garmin and other GPS devices record at ~1 point/second. A 2–4 hour hike produces 4,000–14,000+ track points, often exported as a single-line minified XML file. leaflet-gpx will silently fail or render a blank map on files this large.

**Target:** ~100–150KB, ~800–1,200 track points. If the file is over ~200KB, simplify it.

### How to simplify

Keep every 5th track point using this Python script. The trail line stays smooth — you lose nothing visible:

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
    # Always keep the last point
    if pts and pts[-1] in to_remove:
        to_remove.remove(pts[-1])
    for pt in to_remove:
        trkseg.remove(pt)

tree.write(dst, xml_declaration=True, encoding='UTF-8')
```

Run: `python3 simplify_gpx.py` — then use the output file. If still over 200KB, increase the stride from 5 to 8 or 10.

**Tip for finding summit/key coords:** To find the highest elevation point in a GPX (for a summit stop):
```python
import xml.etree.ElementTree as ET
ns = 'http://www.topografix.com/GPX/1/1'
tree = ET.parse('file.gpx')
pts = list(tree.getroot().iter(f'{{{ns}}}trkpt'))
summit = max(pts, key=lambda p: float(p.find(f'{{{ns}}}ele').text))
print(summit.attrib['lat'], summit.attrib['lon'], summit.find(f'{{{ns}}}ele').text)
```

## Step 3: Verify checklist

- [ ] GPX file is in the same directory as `index.md`
- [ ] GPX file is under ~200KB (simplify if needed — see above)
- [ ] `tour-map` shortcode `gpx=` param matches the exact filename
- [ ] Every stop `id` in front matter matches a `{#anchor}` on an H3 heading
- [ ] Stop `order` values are sequential starting at 1
- [ ] Main entrance / primary stop is `order: 1` (gets the amber star icon)
- [ ] `geo.lat` / `geo.lon` set to approximate tour center
