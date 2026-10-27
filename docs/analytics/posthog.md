# Analytics: PostHog

PostHog (US cloud) is the only runtime analytics. Google Analytics is
commented out in `config/production/hugo.toml` and not loaded.

| | |
| --- | --- |
| Project | `benstrawbridge.com`, id **357270** — [open in PostHog](https://us.posthog.com/project/357270) |
| Ingestion host | `https://t.benstrawbridge.com` (first-party reverse proxy; in the CSP's `script-src` and `connect-src`) |
| UI host | `https://us.posthog.com` |
| Project key | public `phc_…`, from Cloudflare build variable `PUBLIC_POSTHOG_KEY` |
| Loaded where | production builds of `main` only. Previews blank the key; `hugo server` is the development environment and doesn't load it. |
| Internal traffic | Filtered by the project's test-account cohort; use `filterTestAccounts` in queries |

## How it's wired

The theme owns the integration (`themes/ryder/layouts/partials/posthog.html`);
the site only selects it in `config/production/hugo.toml`:

```toml
analytics_provider = "posthog"
posthog_host = "https://t.benstrawbridge.com"
posthog_ui_host = "https://us.posthog.com"
posthog_defaults = "2026-01-30"
posthog_person_profiles = "identified_only"
```

The key comes from `getenv "PUBLIC_POSTHOG_KEY"`, which works only because
`[security.funcs] getenv` allows `^PUBLIC_POSTHOG_`. Without that, Hugo blocks
the read and the theme warns that PostHog is selected but has no key.

Project settings in PostHog (not the repo): autocapture on, web vitals on,
heatmaps on, console-log and performance capture on, **session replay off**.

### Cookies

There is deliberately no `posthog_cookie_domain`: posthog-js has no
`cookie_domain` option (verified against 1.414.0), so it was silently dropped.
`cross_subdomain_cookie` (default on) probes for the domain starting at `.com`,
so the browser logs one `Cookie "dmn_chk_…" has been rejected for invalid
domain` per page load. That line is expected and harmless — don't "fix" it.

## Events

Seen in the last 30 days as of 2026-10-04:

| Event | Source | Properties |
| --- | --- | --- |
| `$pageview` | posthog-js | standard |
| `$web_vitals` | posthog-js (project setting) | LCP / FCP / INP / CLS, spread across events |
| `$rageclick` | autocapture | standard |
| `404` | `assets/js/not-found.js` | `path` (pathname + query), `referrer` (`$direct` if none) |
| `booking_link_click` | `layouts/partials/consulting/cta.html` | `page`, `placement` (`hero`/`closing`/`door-top`/`door-bottom`), `target` (`calendar`) |
| `photo_viewed` | **not emitted by this repo or Ryder v0.5.0** — likely another site or an old build sharing the project. Check before relying on it. | — |

### 404 tracking

`layouts/404.html` (a theme fork) loads `assets/js/not-found.js`. Cloudflare's
`404-page` mode serves `404.html` at the requested URL without a redirect, so
`location` is the missing page. The script is same-origin with SRI (no CSP
change) and no-ops when PostHog isn't loaded. Only browsers that run JS are
counted, so scanner and bot 404s never reach PostHog — deliberately, to keep
them off the event quota. Note `/404.html` itself also shows up in `$pageview`
top pages.

### Adding an event

Use the theme's declarative component — the Alpine **CSP build** silently
ignores inline calls like `@click="posthog.capture('x')"`:

```html
<a href="…" x-data="ryderTrack" @click="track"
   data-track-event="trail_gpx_download"
   data-track-props='{"trail":"strawberry-peak"}'>Download GPX</a>
```

`ryderTrack` (theme `main.js`) forwards to whichever provider is configured and
no-ops when none is loaded. Event names are `snake_case` nouns-then-verbs
(`trail_gpx_download`, `ticket_link_click`). Document new events in the table
above in the same commit. A standalone script (like `not-found.js`) goes in
`assets/js/` and is loaded with `resources.Get … | fingerprint` so SRI covers it.

## Deploy markers

Every successful production deploy creates a PostHog annotation
`benstrawbridge.com production deploy @ <full SHA> · …`, so traffic changes
line up with commits. Setup, troubleshooting and key rotation:
[runbooks/posthog-deploy-tracking.md](../runbooks/posthog-deploy-tracking.md).

## Reading the data

- **PostHog web analytics** dashboard for visitors, top pages, referrers, vitals.
- **PostHog MCP** (available in Claude Code sessions): `query-web-overview`,
  `query-web-stats` (`breakdownBy: "Page"`), `query-trends` for events such as
  `404`. Always confirm event names with `read-data-schema` first.
- Pair traffic with Search Console exports
  ([search-console/README.md](../search-console/README.md)) for search
  impressions and positions, which PostHog can't see.

Baseline numbers live in [operations/site-stats.md](../operations/site-stats.md).
