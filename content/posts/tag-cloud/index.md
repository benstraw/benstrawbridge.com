+++
title = 'Tag Cloud'
date = 2024-05-30T00:19:52-07:00
# draft = true
# summary = ""
# categories = [""]
tags = [
  "Hugo",
  "Tag Cloud"
  ]
# featured_image = ""
homeFeatureIcon = "fa-solid fa-cloud-meatball"
# showTOC = true
+++

## Cloudy days a hoy
I found this partial to create a tag cloud on [Mert Bakir's personal website](https://mertbakir.gitlab.io/hugo/tag-cloud-in-hugo/) and I have been adapting the code to suit my needs for this project, for now I'm just leaving it under this project page until I can decide what to do with it.

{{< taxonomy-cloud >}}

<!--more-->

## Partial 
{{< highlight-github owner=arts-link repo=ryder path=layouts/partials/taxonomy-cloud.html showlink=false  >}}

The next update to come to this tag-cloud partial is the ability to pass in a taxonomy name, since it is currently setup for only tags.