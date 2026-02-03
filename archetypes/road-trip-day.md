+++
title = '{{ replace .File.ContentBaseName "-" " " | title }}'
date = {{ .Date }}
draft = true
hideAsideBar = true
categories = ["road-trip"]
# tags = [
#   "location",
#   "activity"
# ]
# featured_image = ""
# homeFeatureIcon = "fas fa-road"

[maps]
# latitude = ""
# longitude = ""
+++

## Overview

Brief overview of the day's journey.

<!--more-->

## Route

Describe the route taken, roads traveled, and any interesting stops along the way.

## Highlights

- Key moment 1
- Key moment 2
- Key moment 3

## Photos

{{< picture
  alt="Description"
  src="photo.jpg"
  title="Photo Title"
>}}

## Notes

Any additional thoughts, reflections, or details about the day.
