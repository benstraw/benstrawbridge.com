# Content Security Policy

**Required deployment check.** Any change that adds or changes an external host
for scripts, images, map tiles, fonts, embeds, analytics, or fetch/XHR must be
verified against the rendered `Content-Security-Policy` before pushing. The
site breaks quietly when an outside source is added without it: the browser
blocks the request and the page just looks wrong.

## How it's built

The policy is a `<meta http-equiv="Content-Security-Policy">` tag emitted by the
theme (`themes/ryder/layouts/partials/head/csp.html`), not a response header —
Cloudflare doesn't touch it. The theme's base policy covers its own assets,
Google Fonts and the configured analytics provider. The site extends it under
`[params.csp]`, merged across environments:

| Directive | Site addition | Where | Why |
| --- | --- | --- | --- |
| `img-src` | `tile.openstreetmap.org`, `*.tile.openstreetmap.org`, `server.arcgisonline.com`, `basemap.nationalmap.gov`, `i.scdn.co` | `config/_default/hugo.toml` | Leaflet tiles on trail maps; Spotify artist images |
| `script-src` | `'unsafe-inline'` | `config/production/hugo.toml` | See below |

Production policy as rendered on 2026-10-04:

```
default-src 'self'; script-src 'self' https://t.benstrawbridge.com 'unsafe-inline';
style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; font-src 'self' https://fonts.gstatic.com;
img-src 'self' data: …tiles… https://i.scdn.co; connect-src 'self' https://t.benstrawbridge.com;
frame-ancestors 'none'; form-action 'self'; base-uri 'self'; object-src 'none';
```

Available keys: `imgSrc`, `scriptSrc`, `styleSrc`, `connectSrc`, `fontSrc`,
`frameSrc`, `embeds` (presets: youtube, vimeo, soundcloud, spotify, umap),
`scriptSrcHashes`, `extraDirectives`, `disabled`. The theme's file header is the
reference.

### Why `'unsafe-inline'` in script-src

Ryder v0.3.0 stopped adding it automatically. The site still needs it: the
`tour-map` shortcode builds a different inline script per trail (it
interpolates the GPX path and stops JSON, so a hash can't cover it) and uses
inline `onclick`/`onmouseover` attributes; `layouts/trails/single.html` and
`layouts/grid-basic/baseof.html` carry inline scripts too. To drop it, move those
scripts into `assets/js/extended.js`, convert `on*` attributes to
`addEventListener`, and pass page data via `data-*` attributes. Don't add new
inline scripts in the meantime.

## The check

```bash
npm run cf:build
grep -o 'Content-Security-Policy" content="[^"]*' public/<page>/index.html
```

Then load the page in a browser (or Playwright) and confirm there are no CSP
violations in the console. Check the **specific page** that uses the new host —
trail pages, artist pages and the home page differ in what they load.

Things that have needed this: map tiles (OSM, USGS, Esri), Spotify images
(`i.scdn.co`), PostHog (`t.benstrawbridge.com`), Leaflet plugins, embeds, remote
fonts.

## Related, but separate

- **Build-time fetches** (`resources.GetRemote`) are governed by the build
  environment's network, not the CSP. See
  [development/local-and-cloud.md](../development/local-and-cloud.md#remote-fetches-and-try).
- **Alpine CSP build**: `@alpinejs/csp` can't evaluate calls or multi-statement
  expressions in directives and fails silently. Unrelated to the CSP header but
  the same family of "works locally, dead in production" bugs. The theme's
  `cspLint.js` flags them in development.
- **Previews** use `baseURL = /` precisely so `'self'` matches on
  `*.workers.dev`.
