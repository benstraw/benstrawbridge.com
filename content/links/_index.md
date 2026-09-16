+++
description = "The link graveyard: where Ben Strawbridge remembers what he found on the web — things learned, things stumbled upon, and friends' sites."
title = 'Link Graveyard'
date = 2024-01-18T11:50:06-08:00
# draft = true
tags = [
  "hugo",
  "themes",
  "css",
  "images",
  "blogroll"
]
showTOC = true
TocOpen = true
# summary = "The link graveyard is my page for remembering where I found stuff – whether it's something I learned, something cool I stumbled upon, or maybe just a friend's site."
[menu]
 [menu.main]
  name = "Links"
  weight = 100
  identifier = 'links'
[[cascade]]
  showCardLinkOverlay = false
  homeFeatureIcon = "fa-solid fa-link"
  logo_tagline = "LINK GRAVEYARD"
  cardCategoryColorsDefault = "bg-gradient-to-bl from-pink-600 to-red-600"
  [cascade.twClasses]
    headerBackgroundFrameOuter = "bg-gradient-to-r from-rose-500 to-rose-800 text-neutral-100"
    headerBackgroundFrameInner = ""

# Individual link entries are bookmark data for this list page, not content
# worth indexing on their own. `_target.kind = "page"` scopes this rule to
# the entries themselves (Kind "page"), not this _index.md (Kind "section")
# — an untargeted cascade applies to the defining page too, which silently
# noindexed /links/ itself and dropped it from the sitemap on the first pass.
# robotsNoIndex adds the noindex meta (see
# themes/ryder/layouts/partials/head.html); outputs drops the OGCard build
# output entirely (og_generate=false alone only blanks its contents, it
# doesn't stop Hugo from writing the file — see layouts/partials/og-card/card.html);
# sitemap.disable drops entries from sitemap.xml, since a noindex page has no
# business being listed there. Tags stay live (no `_build` change), so
# entries still show up on /tags/.
[[cascade]]
  robotsNoIndex = true
  og_generate = false
  outputs = ["HTML"]
  [cascade.sitemap]
    disable = true
  [cascade._target]
    kind = "page"

+++

The link graveyard is my page for remembering where I found stuff – whether it's something I learned, something cool I stumbled upon, or maybe just a friend's site.

<!--more-->
