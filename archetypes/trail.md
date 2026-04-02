+++
title = "{{ replace .Name "-" " " | title }}"
date = {{ .Date }}
description = ""
gpx = ""
tour = true
tourType = "Hiking Tour"

[geo]
  lat = 0.0
  lon = 0.0
  neighborhood = ""
  city = ""
  state = "CA"

[[stops]]
  id = "trailhead"
  name = "Trailhead"
  lat = 0.0
  lon = 0.0
  order = 1
  blurb = ""
+++

{{</* tour-map gpx="" */>}}
