+++
title = "Hiking and Walking Trails in Los Angeles"
date = 2026-03-22
description = "Hiking and walking trail guides for Los Angeles, from Westchester and Playa Vista to the San Gabriel Mountains, with maps and parking."
# The card the /trails/ grid renders its children with — read by
# themes/ryder/layouts/_default/list.html off this page. Distinct key from the
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
+++

These are the trail guides I write after walking the route myself. Each one has a map, what to look for along the way, and the honest answer to where to park. The guides start close to home on the west side of Los Angeles and reach out into the mountains.

## Near Westchester and Playa Vista

The walks I do most often are around Westchester, Playa Vista, and Playa del Rey.

- [Bluff Creek Trail](/trails/bluff-creek-trail/): a 4-mile loop on the bluffs below LMU, with ocean and mountain views and three access points.
- [Playa Vista Parks Walking Tour](/trails/pv-tour/): a self-guided loop through Playa Vista's parks and dog parks, including where to park for the Bluff Creek Trail.
- [Bluff Trail](/trails/bluff-trail/): the short bluff path just west of LMU. It is a different trail from the Bluff Creek Trail.
- [Ballona Creek Bike Path](/projects/hiking/westchester-playa-vista-playa-del-rey-hiking-guide/ballona-creek-bike-path/), [Ballona Wetlands](/projects/hiking/westchester-playa-vista-playa-del-rey-hiking-guide/ballona-wetlands/), and [Del Rey Lagoon](/projects/hiking/westchester-playa-vista-playa-del-rey-hiking-guide/del-rey-lagoon/): places to walk in Playa del Rey.

## Mountains and farther out

Longer hikes in the San Gabriel Mountains and beyond are listed below, with more on the way.
