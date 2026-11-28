+++
title = "Hiking and Walking Trails in Los Angeles"
date = 2026-03-22
description = "Hiking and walking trail guides for Los Angeles, from Westchester and Playa Vista to the San Gabriel Mountains, with maps and parking."
# The card the /trails/ grid renders its children with — read by
# layouts/trails/list.html (our override of the theme list layout) off this page. Distinct key from the
# cascaded cardType below: this one says "what card do the items in my list
# use", cardType says "what card does this page use wherever it is listed".
listCardType = "-trail"
[menu]
 [menu.main]
  weight = 5
  identifier = "Trails"
  name = "Trails"
[cascade]
  # OGCard renders the social card source at /trails/<slug>/og-card.html.
  # See scripts/generate-og.mjs and docs/seo/og-cards.md.
  outputs = ["HTML", "OGCard"]
  # Each trail page renders as layouts/partials/card-trail.html wherever it is
  # listed. Resolved per page by layouts/partials/utils/card-type.html.
  cardType = "-trail"
  logo_tagline = "HIKING MAPS AND GUIDES"
  sectionTitle = "benstrawbridge.com"
  cardCategoryColorsDefault = "bg-gradient-to-r from-blue-600 to-violet-600 text-neutral-200"
  [cascade.twClasses]
    headerBackgroundFrameInner = "bg-[url('/images/header-bg/ben-mt-wilson-summit-by-thomas.webp')] bg-cover bg-bottom h-[300px]"
    headerBackgroundFrameOuter = "bg-gradient-to-r from-blue-600 to-violet-600 text-neutral-200"

# Groups on the landing page, in order. Rendered by layouts/trails/list.html;
# each trail's `area` front matter must match a `key` here.
[[areas]]
  key = "local"
  title = "Near Westchester, Playa del Rey and Playa Vista"
  intro = "The walks I do most often, close to home on the west side of Los Angeles."
[[areas]]
  key = "la"
  title = "Around Los Angeles"
  intro = "Hikes in and around the city."
[[areas]]
  key = "angeles"
  title = "Angeles National Forest and the San Gabriels"
  intro = "Longer, steeper hikes in the mountains north of the city. Bring water and check trail conditions first."
[[areas]]
  key = "far"
  title = "Farther out"
  intro = "Trips outside the Los Angeles area."
+++

These are the trail guides I write after walking the route myself. Each one has a map, what to look for along the way, and the honest answer to where to park. They start close to home in Westchester, Playa del Rey and Playa Vista, then reach out across Los Angeles and into the mountains.
