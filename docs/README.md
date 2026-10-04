# benstrawbridge.com knowledge base

How this site is built, written, deployed and measured. Start here; every page
below is short enough to read before you touch the area it covers.

The site is a Hugo static site on the [Ryder](https://github.com/arts-link/ryder)
theme (git submodule), styled with Tailwind, made interactive with Alpine.js
(CSP build), deployed as a static-assets-only Cloudflare Worker, and measured
with PostHog and Google Search Console.

## Map

| Area | Page | Read it before… |
| --- | --- | --- |
| Architecture | [architecture/overview.md](architecture/overview.md) | anything — stack, repo layout, config files, data flow |
| Development | [development/local-and-cloud.md](development/local-and-cloud.md) | building, running checks, or working in a Claude Code cloud session |
| | [development/checks.md](development/checks.md) | pushing — the quality gates and what each one guards |
| Content | [content/sections.md](content/sections.md) | adding or moving content; archetypes, front matter, taxonomies |
| | [content/writing-style.md](content/writing-style.md) | writing a post, link, trail, doc, code comment or commit message |
| | [content/walking-tour-guide-spec.md](content/walking-tour-guide-spec.md) | building a `/trails/` page (also the `new-walking-tour` command) |
| Theme | [theme/ryder-forks.md](theme/ryder-forks.md) | bumping Ryder, or editing a forked partial |
| | [theme/ryder-issue-footer-taxonomy.md](theme/ryder-issue-footer-taxonomy.md) | filing the upstream taxonomy issue (draft) |
| SEO | [seo/invariants.md](seo/invariants.md) | changing titles, descriptions, headings, outputs, robots, redirects |
| | [seo/og-cards.md](seo/og-cards.md) | adding content (it needs a card) or touching the OG pipeline |
| | [search-console/README.md](search-console/README.md) | comparing Search Console exports |
| Deployment | [deployment/cloudflare.md](deployment/cloudflare.md) | changing hosting, headers, previews, redirects, build variables |
| | [deployment/csp.md](deployment/csp.md) | adding **any** external host (required check) |
| Analytics | [analytics/posthog.md](analytics/posthog.md) | adding events, changing PostHog config, reading traffic |
| | [runbooks/posthog-deploy-tracking.md](runbooks/posthog-deploy-tracking.md) | deploy markers: setup, troubleshooting, key rotation |
| Data | [data/spotify-listening.md](data/spotify-listening.md) | touching `data/spotify/` or the `/listening/` section |
| Stats | [operations/site-stats.md](operations/site-stats.md) | quoting a page count or sizing a change |
| Automation | [operations/ci-and-automation.md](operations/ci-and-automation.md) | editing GitHub workflows or Claude automation |
| History | [history/aws-teardown.md](history/aws-teardown.md) | never, unless you are deleting the retired AWS tooling |

## Rules for this knowledge base

- **One home per fact.** If two pages need the same fact, one owns it and the
  other links. Code comments may carry the *why* for the line they sit on, but
  point here for anything longer.
- **Write what is true now.** Superseded behaviour goes in one sentence of
  history ("until 2026-09 this was…") only when it explains why the current
  shape exists. Don't leave instructions for a system that is gone.
- **Date your measurements.** Counts, timings and "verified" claims carry the
  date or Hugo/Ryder version they were measured on, and say how to re-measure.
- **Verify against built output**, not templates. Many facts here are decided by
  fallback chains; `public/` is the only authority.
- **Update the doc in the same commit** as the behaviour change. A PR that
  changes something documented here and not the doc is incomplete.
- Style for these pages is in [content/writing-style.md](content/writing-style.md#docs-comments-and-commits).
