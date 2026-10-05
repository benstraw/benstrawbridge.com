# Agent Instructions

benstrawbridge.com is a Hugo static site on the Ryder theme (git submodule at
`themes/ryder`, pinned to `v0.5.0`), styled with Tailwind, made interactive
with the Alpine.js **CSP build**, served as a static-assets-only Cloudflare
Worker, and measured with PostHog and Google Search Console.

**The knowledge base is [`docs/`](docs/README.md).** Read the page for the area
you're touching before you change it, and update it in the same commit when
behaviour changes.

## Where to look

| Before you… | Read |
| --- | --- |
| Do anything (stack, layout, config, data flow) | [docs/architecture/overview.md](docs/architecture/overview.md) |
| Build, run, or work in a cloud session | [docs/development/local-and-cloud.md](docs/development/local-and-cloud.md) |
| Push | [docs/development/checks.md](docs/development/checks.md) |
| Add or move content | [docs/content/sections.md](docs/content/sections.md) |
| Write anything — page, link, trail, doc, comment, commit | [docs/content/writing-style.md](docs/content/writing-style.md) |
| Build a trail / walking tour | [docs/content/walking-tour-guide-spec.md](docs/content/walking-tour-guide-spec.md), `/new-walking-tour` |
| Bump Ryder or edit a forked partial | [docs/theme/ryder-forks.md](docs/theme/ryder-forks.md) |
| Touch titles, descriptions, headings, outputs, robots | [docs/seo/invariants.md](docs/seo/invariants.md) |
| Add content or touch OG cards | [docs/seo/og-cards.md](docs/seo/og-cards.md) |
| Change hosting, headers, previews, redirects | [docs/deployment/cloudflare.md](docs/deployment/cloudflare.md) |
| Add any external host | [docs/deployment/csp.md](docs/deployment/csp.md) |
| Add events or read traffic | [docs/analytics/posthog.md](docs/analytics/posthog.md) |
| Touch `data/spotify/` or `/listening/` | [docs/data/spotify-listening.md](docs/data/spotify-listening.md) |
| Quote a number about the site | [docs/operations/site-stats.md](docs/operations/site-stats.md) |
| Edit workflows or agent config | [docs/operations/ci-and-automation.md](docs/operations/ci-and-automation.md) |

## Non-negotiables

- **Deploys:** Cloudflare Workers Builds deploys `main`; every other branch is a
  noindex, analytics-free preview. AWS Amplify is retired — never treat it as a
  deployment path. Every successful production build gets a PostHog deploy
  marker ([runbook](docs/runbooks/posthog-deploy-tracking.md)).
- **CSP is a required check.** Any change that adds or changes an external host
  for scripts, images, tiles, fonts, embeds, analytics, or fetch/XHR must be
  verified against the rendered `Content-Security-Policy` before pushing.
- **Alpine CSP build:** no function calls, member calls, arrows or multiple
  statements in directives — they fail silently. Use a registered component
  and `data-*` attributes.
- **Verify against built HTML** in `public/`, not templates.
- **New content gets an OG card** (`npm run og:generate -- --only /path/`) and a
  real `description`. Trail cards can't be generated in a cloud session.
- **Redirects are 301s in `static/_redirects`**, never Hugo `aliases`, for any
  URL that has ranked.
- **Theme changes go upstream** to `arts-link/ryder`; don't edit `themes/ryder`
  in this repo's history.
- **Secrets:** the PostHog `phx_…` CI key lives only in GitHub Actions; the
  `phc_…` browser key is public. Never commit either.
- `bd` (beads) has been removed from this project. Don't use `bd` commands or
  assume a `.beads` database exists.

## Landing the Plane (Session Completion)

**When ending a work session**, you MUST complete ALL steps below. Work is NOT complete until `git push` succeeds.

**MANDATORY WORKFLOW:**

1. **Run quality gates** (if code changed) — see [docs/development/checks.md](docs/development/checks.md)
2. **PUSH TO REMOTE** - This is MANDATORY:
   ```bash
   git pull --rebase
   git push
   git status  # MUST show "up to date with origin"
   ```
3. **Clean up** - Clear stashes, prune remote branches
4. **Verify** - All changes committed AND pushed
5. **Hand off** - Provide context for next session

**CRITICAL RULES:**
- Work is NOT complete until `git push` succeeds
- NEVER stop before pushing - that leaves work stranded locally
- NEVER say "ready to push when you are" - YOU must push
- If push fails, resolve and retry until it succeeds
- Treat CSP as a required deployment check. Any change that adds or changes external hosts for scripts, images, tiles, fonts, embeds, analytics, or fetch/XHR must be verified against the rendered `Content-Security-Policy` before pushing.
