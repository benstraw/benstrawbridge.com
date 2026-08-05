+++
# The home page's <title> tag comes from site.Title, not from this field
# (themes/ryder/layouts/partials/head.html renders site.Title when .IsHome), so
# this only drives the social-card headline: og:title and twitter:title. It used
# to duplicate site.Title, which made every shared link read as a consulting
# business rather than a personal site.
title = 'Home Page'
# The OG image keeps the old wording on purpose. get-featured-image.html draws
# .LinkTitle over assets/images/og/og_image_default.jpg, so without this the
# image's large green line would follow the title above; pinning it holds the
# card art exactly as it was, logo and consulting tagline included.
ogTitleText = 'Ben Strawbridge Dot Com Consulting'
# description = 'the domain to email me at would just so happen to be benstrawbridge.com'
# featured_image = '/images/maui-sunset.webp'
date = 2024-01-02T11:58:15-08:00
draft = false 
# Paginated home-feed cards can contain Leaflet shortcodes in their summaries.
loadLeaflet = true
listSortBy = "Lastmod"
listSortOrder = "desc"
# enabledebugpanel = true
# type = 'hidden-home'
# randomizeBackground = true
# logo_collapse = true
# [twClasses]
    # headerBackgroundFrame = "bg-gradient-to-r from-violet-950 to-rose-950 text-neutral-100  border-b border-fuchsia-600"
+++
