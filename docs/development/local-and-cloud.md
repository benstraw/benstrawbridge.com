# Local development and cloud sessions

## Everyday commands

```bash
git submodule update --init --recursive   # first time: fetch the Ryder theme
npm install                               # Tailwind, PostCSS, Playwright, wrangler, Font Awesome

hugo server            # dev server, development environment, live reload
hugo server -D         # include drafts
hugo                   # production-environment build into public/
npm run cf:build       # exactly what Cloudflare runs (production unless WORKERS_CI_BRANCH says otherwise)
WORKERS_CI_BRANCH=x npm run cf:build      # the preview build path
npx wrangler deploy --dry-run             # validate wrangler.jsonc against public/, no login needed
```

`hugo server` runs the **development** environment, so it has no PostHog, no
autoprefixer and no production CSP widening. Check anything analytics- or
CSP-related against a production build (`hugo` or `npm run cf:build`).

New content: see [content/sections.md](../content/sections.md#creating-content).
Quality gates before pushing: [checks.md](checks.md).

## Claude Code on the web

Use the **Ryder / Hugo** cloud environment (`env_01MrAybFDCw6e1U8bKcqRkWi`),
shared by every site on the theme. Its setup script installs Hugo extended
into the cached snapshot. Pick it in the environment selector when starting a
session; no committed file can choose it for you.

A fresh container clones the repo with an empty `themes/ryder`, possibly no
Hugo, and no `node_modules`. `.claude/hooks/session-start.sh` (registered in
`.claude/settings.json`) restores all three and is a no-op locally:

1. `git submodule update --init --recursive`
2. Hugo extended `0.164.0`, checksum-verified, only if the right version is
   missing (about a minute when it has to download, because hook writes land
   after the snapshot)
3. `npm install`

**If `themes/ryder` is empty, the hook didn't run.** Fix that before trusting
anything you read in `layouts/` — an empty theme makes the site look like it
has a fraction of its templates.

### What doesn't work in a cloud session

| Thing | Why | What happens |
| --- | --- | --- |
| `highlight-github` shortcode (3 posts: `tag-cloud`, `ingredients-section`, `recipe-template-for-ryder-theme`) | All GitHub HTTP goes through a credential proxy that serves only git and the GitHub tools; `api.github.com/repos/…` returns 403 whatever the network policy. (The API root returns 200, so probing it is misleading.) | Theme (Ryder ≥ v0.3.2) warns and renders a link to the file instead. Production does the same because `highlightGithubStrict = false`. |
| Trail OG cards | Chromium's tile requests get `ERR_CONNECTION_RESET` through the agent proxy even though `curl` reaches the tile hosts (verified 2026-08-05) | `npm run og:generate` fails loudly for `/trails/` cards. Generate them locally. See [seo/og-cards.md](../seo/og-cards.md). |
| `npx playwright install` | Downloads ~170MB per session | Don't. The OG scripts fall back to `/opt/pw-browsers/chromium`. |

Non-trail OG cards, production builds, preview builds and every check in
[checks.md](checks.md) work in a cloud session.

The books content adaptor used to fetch covers from `gohugo.io` at build time;
since 2026-10-04 they are vendored in `assets/images/books/`, so that host is no
longer a build dependency.

### Remote fetches and `try`

Any `resources.GetRemote` must be wrapped in `try`. A blocked host raises a hard
template error rather than setting `.Err`, so `{{ with … }}{{ else }}` never
catches it, and `.Err` on the returned resource was removed in Hugo 0.141 —
reading it aborts the build. `$attempt.Err` on the `try` result is the correct
check. Build-time fetches are governed by the network policy; what the
*browser* may load is governed by the CSP. A host can pass one and fail the
other.

## PostCSS and Node's permission model

Hugo runs PostCSS under Node's permission model, which only allows reads inside
the project. In production `postcss.config.js` adds autoprefixer, whose
browserslist would otherwise walk above the repo root and die with
`ERR_ACCESS_DENIED / FileSystemRead` (the first Cloudflare build failed on
`/opt/buildhome/package.json`). The config passes
`overrideBrowserslist: 'defaults'` and `stats: {}` to skip both lookups.

- **Don't** add a `.browserslistrc` or a `browserslist` key in `package.json` —
  neither is read. Change targets in `postcss.config.js`.

## Tailwind

`tailwind.config.js` uses Ryder's preset and scans `config/**/*.toml`, theme
and site layouts, and `content/**/*.md`. Consequences:

- A class assembled in JavaScript is never generated. Put the literal class in a
  template, or add it to `safelist` (the share-button classes already are).
- Theme colours are `--ryder-*` CSS variables exposed as `ryder-brand-*`,
  `ryder-brand-alt-*`, `ryder-accent-*`. Repoint them with `[params.colors]`
  using **RGB channel triplets** (`"244 63 94"`), never hex — hex silently
  breaks every opacity modifier. `[params.twClasses]` strings are literal.
- Dark mode is class-based. `2xl` is capped at 1280.
