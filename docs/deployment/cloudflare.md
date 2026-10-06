# Cloudflare deployment

Production is a **static-assets-only Cloudflare Worker**, built and deployed by
Cloudflare Workers Builds from `main`. There is no server code. AWS Amplify is
retired and is not a fallback ([history/aws-teardown.md](../history/aws-teardown.md)).

## Pieces

| Piece | Where |
| --- | --- |
| Build command | `npm run cf:build` → `scripts/cf-build.sh` |
| Deploy / preview commands | `npx wrangler deploy` / `npx wrangler versions upload` (run by Workers Builds) |
| Worker config | `wrangler.jsonc`: name `benstrawbridge-com`, serves `./public`, `html_handling: auto-trailing-slash`, `not_found_handling: 404-page` |
| Path redirects | `static/_redirects` |
| Response headers | `static/_headers` (shadows `themes/ryder/static/_headers`) |
| Apex → www | Cloudflare **Redirect Rule** on the zone (not in the repo) |
| Build variables | Cloudflare dashboard: `HUGO_VERSION`, `PUBLIC_POSTHOG_KEY`, `PUBLIC_POSTHOG_HOST` |
| Deploy marker | `.github/workflows/posthog-deploy-annotation.yml` — [runbook](../runbooks/posthog-deploy-tracking.md) |

## Current production configuration

- Worker `benstrawbridge-com` (must match `wrangler.jsonc`), production branch
  `main`.
- Custom domains `www.benstrawbridge.com` and `benstrawbridge.com`.
- Apex Redirect Rule: hostname `benstrawbridge.com` → dynamic
  `concat("https://www.benstrawbridge.com", http.request.uri.path)`, 301,
  preserve query string. Hugo builds absolute `www` URLs, so serving HTML from
  the apex would make CSP `'self'` reject its own assets.
- `PUBLIC_POSTHOG_KEY` is the public `phc_…` project key. The private
  deploy-annotation key lives only in GitHub Actions — never in Cloudflare.

## The build

`cf-build.sh`:

1. `git submodule update --init --recursive` (theme).
2. Ensures Hugo **extended**. Cloudflare installs it from `HUGO_VERSION`, which
   must name the extended build, not just a number. If it's missing, the script
   downloads the version number it finds there (default `0.164.0`) into
   `node_modules/.cache/hugo/`.
3. `hugo --gc --minify --cleanDestinationDir`.

It does **not** run `og:check` or any test; see [development/checks.md](../development/checks.md).

### Previews

Every non-`main` branch is a preview (`WORKERS_CI_BRANCH` decides; unset means a
local run, treated as production). Previews differ in three ways:

- `PUBLIC_POSTHOG_KEY` is blanked — preview traffic never reaches analytics.
- `baseURL` is `/` (override with `CF_PREVIEW_BASEURL`); absolute `www` URLs
  would fail CSP `'self'` on `*.workers.dev`.
- `X-Robots-Tag: noindex` is appended to `public/_headers`.

Test both paths locally or in a cloud session:

```bash
npm run cf:build
WORKERS_CI_BRANCH=anything npm run cf:build
npx wrangler deploy --dry-run
```

## Headers

The CSP is a `<meta>` tag rendered by the theme, **not** a response header, so
hosting doesn't change it ([csp.md](csp.md)).

The theme ships a Netlify-style `_headers` whose catch-all `/*` rule overlaps
`/css/*`, `/js/*` and `/images/*`, and Cloudflare **joins** values of a header set
by more than one matching rule (fingerprinted CSS would ship as "…immutable,
public, max-age=0, must-revalidate"). Its `/images/*` rule also marks
unfingerprinted files immutable. The site's `static/_headers` shadows it with
non-overlapping rules (`:file` matches one segment) until
[arts-link/ryder#115](https://github.com/arts-link/ryder/issues/115) ships;
removal is tracked in
[benstraw/benstrawbridge.com#128](https://github.com/benstraw/benstrawbridge.com/issues/128).
**Keep rules non-overlapping for any one header.**

## Redirects

Path redirects live in `static/_redirects`, copied to `public/_redirects`.
Syntax `source target status`; `*` in the source, `:splat` in the target; first
match wins, so specific rules go above wildcards. Paths only — host redirects
(apex → www) are zone Redirect Rules.

Use a 301 here, not a Hugo `alias`, for anything that has ever ranked
([seo/invariants.md](../seo/invariants.md#redirects-vs-aliases)). The bluff-creek
alias in `content/trails/bluff-creek-trail/index.md` stays until its 301 is
confirmed live:

```bash
curl -sI https://benstrawbridge.com/trails/ | grep -i '^location'   # → https://www.benstrawbridge.com/trails/
curl -sI https://www.benstrawbridge.com/projects/hiking/westchester-playa-vista-playa-del-rey-hiking-guide/bluff-creek-trail/ | grep -i '^location'
curl -sI https://www.benstrawbridge.com/projects/content-adaptors/spotify/foo/ | grep -i '^location'
curl -sI https://www.benstrawbridge.com/listening/artists/page/2/ | grep -i '^location'   # → /listening/a-z/
```

Placeholders work too: `/listening/artists/page/:n/` covers the retired
paginated artist index (pages 2–40 and beyond) in one rule, so page counts never
need listing. Placeholder and splat rules count against Cloudflare's 100
dynamic-redirect limit; plain paths against the 2,000 static limit. To test
locally, build and serve `public/` with `npx wrangler dev`, then `curl -I`.

## 404s

`not_found_handling: 404-page` serves `public/404.html` with status 404 at the
requested URL (no redirect). The page reports to PostHog —
[analytics/posthog.md](../analytics/posthog.md#404-tracking).

## Rollback

Cloudflare keeps prior Worker versions. Roll back from the dashboard
(Workers → `benstrawbridge-com` → Deployments), or revert the commit on `main`
and let Workers Builds redeploy. A revert also produces a fresh PostHog deploy
marker; a dashboard rollback does not.
