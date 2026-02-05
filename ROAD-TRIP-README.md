# Road Trip Section

This section contains a mini-site for documenting road trip adventures.

## Structure

- `_index.md` - Main landing page for the road trip section
- `day-XX/index.md` - Individual day pages (where XX is the day number)

## Creating a New Day Page

You can create a new day page in two ways:

### Method 1: Using Hugo's new content command with the archetype

```bash
hugo new content --kind road-trip-day projects/road-trip/day-03/index.md
```

This will use the `archetypes/road-trip-day.md` template to generate a new day page with all the standard sections.

### Method 2: Manual creation

1. Create a new directory: `content/projects/road-trip/day-XX/`
2. Create an `index.md` file in that directory
3. Copy the frontmatter and structure from an existing day or the archetype

## Adding Photos

1. Place photo files in the same directory as the day's `index.md` file (e.g., `day-01/photo.jpg`)
2. Reference them using the picture shortcode:

```
{{< picture
  alt="Description of photo"
  src="photo.jpg"
  title="Photo Title"
>}}
```

## Maps Integration

To add a map to a day page, uncomment and fill in the `[maps]` section in the frontmatter:

```toml
[maps]
latitude = "33.966613"
longitude = "-118.426178"
```

Then add a leaflet shortcode in your content:

```
{{< leaflet id="day-01-map" lat="33.966613" lon="-118.426178" zoom="10" markerLat="33.966613" markerLon="-118.426178" markerPopup="Location name" >}}
```

## Publishing

- Pages start as `draft = true`
- When ready to publish, change `draft = true` to `draft = false` (or remove the line entirely)
- Run `hugo server` to preview locally
- Run `hugo build` to build for production
