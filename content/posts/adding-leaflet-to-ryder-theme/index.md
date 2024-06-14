+++
title = 'Adding Leaflet to Ryder Theme'
date = 2024-05-10T14:19:38-07:00
homeFeatureIcon = "fa-solid fa-map-location-dot"
tags = [
  "Hugo",
  "Leaflet.js",
  "Mapping",
  "Web Development",
  "Shortcodes",
  "OpenStreetMap",
  "JavaScript",
  "Ryder Theme",
  "Interactive Maps",
  "Open Source"
]
# draft = true
+++
<!-- Latitude: 39.9057° N
Longitude: 75.1665° W -->

{{< leaflet id="bankit" lat="39.9057" lon="-75.1665" zoom="16.5" markerLat="39.9057" markerLon="-75.1665" markerPopup="Life at the Bank!" divHeight="250px" >}}

I made this quick and easy shortcode to get started using leaflet.js in the [Ryder Theme for Hugo Websites](https://arts-link.github.io/ryder/), as I add more features supported by leaflet to the shortcode I might update this page. 

<!--more-->
## Steps taken

- I found this blog post over at [osgav.run](https://osgav.run/lab/hugo-leaflet-integration.html) which reminded me of [leafletjs](https://leafletjs.com/). I had worked on a mapping project years ago and used leaflet for it, but hadn't checked it out since around 2018.
- I downloaded leaflet.js from their [downloads page](https://leafletjs.com/download.html)
- I copied the extracted zip to the `/static` directory of the ryder theme.
- I added the needed files to the head. 
  - TODO: only include them in when leaflet is being used.

{{< highlight go-html-template >}}
<link rel="stylesheet" href="{{ site.BaseURL}}leaflet/leaflet.css" />
<script src="{{ site.BaseURL}}leaflet/leaflet.js"></script>
{{< /highlight >}}

- I created the shortcode `leaflet.js`
```go-html-template
{{- $id := .Get "id" | default "map1" }}
{{- $lat := .Get "lat" | default "51.505" }} 
{{- $lon := .Get "lon" | default "-0.09" }} 
{{- $zoom := .Get "zoom" | default "13" }} 
{{- $markerLat := .Get "markerLat" | default "51.5" }} 
{{- $markerLon := .Get "markerLon" | default "-0.09" }} 
{{- $markerPopup := .Get "markerPopup" | default "hi" }}

<div id="{{ $id }}" style="height: 400px;"></div>
<script>
  var map = L.map('{{ $id }}').setView([{{ $lat }}, {{ $lon }}], {{ $zoom }});

  L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
    attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
  }).addTo(map);

  {{ with $markerLat }}
  L.marker([{{ $markerLat }}, {{ $markerLon }}]).addTo(map)
    .bindPopup('{{ $markerPopup }}');
  {{ end }}
</script>
<div>Debug Info: ID={{ .Get "id" }}, Lat={{ .Get "lat" }}, Lon={{ .Get "lon" }}, Zoom={{ .Get "zoom" }}</div>
```
- I added the shortcode to my post about [westchester hiking]({{< ref "/projects/hiking/westchester-playa-vista-playa-del-rey-hiking-guide/" >}})

{{< highlight go-html-template >}}
{{</* leaflet id="map1" lat="33.966613" lon="-118.426178" zoom="13.5" markerLat="33.9716" markerLon="-118.4363" markerPopup="Green Space right by LAX!" */>}}
{{< /highlight >}}

### Resources

- [openstreetmaps copyright and attribution rules](https://www.openstreetmap.org/copyright)
