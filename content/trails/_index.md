+++
title = "Trails"
date = 2026-03-22
description = "Self-guided hiking and walking tour guides for Los Angeles — with maps, parking, and stop-by-stop descriptions."
# The card the /trails/ grid renders its children with — read by
# themes/ryder/layouts/_default/list.html off this page. Distinct key from the
# cascaded cardType below: this one says "what card do the items in my list
# use", cardType says "what card does this page use wherever it is listed".
listCardType = "-trail"
[menu]
 [menu.main]
  weight = 5
  identifier = "Trails"
[cascade]
  # OGCard renders the social card source at /trails/<slug>/og-card.html.
  # See scripts/generate-trail-og.mjs.
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

These are guides I've put together for walks I do regularly around West LA. Each one has a map, turn-by-turn stops with what to look for, and the honest answer to where to park. Most work as standalone walks or as extensions of the Bluff Creek Trail loop.
