# Checks and quality gates

There is no CI test job: Cloudflare's build is the only automated gate, and it
only proves the site builds. Everything below is run by hand (or by the agent)
before pushing. All of it works in a Claude Code cloud session.

## Before every push that changes code or content

```bash
npm run cf:build            # production build exactly as Cloudflare runs it
```

Then, depending on what changed:

| Changed | Run | Guards |
| --- | --- | --- |
| Any new or edited `.md` page | `npm run og:generate -- --only /path/` then `npm run og:check` | The page has a fresh OG card. `og:check` warns rather than fails, and deploys don't run it — fix the warning anyway. |
| OG templates or scripts | `npm run og:test`, `npm run og:check`, `npm run og:gallery:check` | Pure-function tests for `og-lib.mjs`; manifest freshness; `/og-tests/` galleries current |
| A Font Awesome icon class anywhere | `npm run test:fa-icons` | Every `fa-*` class in templates/content is registered in `assets/js/extended.js` (`library.add`). An unregistered icon renders as nothing. |
| Card partials, `utils/card-type.html`, `list.html`, `home.html` | `npm run test:list-cards` (after a build) | Per-page card selection: `cardImage` / `cardType` opt-ins, trail card precedence, generated pages can't opt in |
| `.github/workflows/posthog-deploy-annotation.yml` | `npm run test:posthog-deploy` | Production-only filter, pinned action, `continue-on-error`, SHA dedupe prefix |
| Any external host (script, image, tile, font, embed, analytics, fetch) | Inspect the rendered `<meta http-equiv="Content-Security-Policy">` | **Required.** See [deployment/csp.md](../deployment/csp.md). |
| Titles, descriptions, headings, outputs, robots | Grep the built `public/` | [seo/invariants.md](../seo/invariants.md) |
| `wrangler.jsonc` | `npx wrangler deploy --dry-run` | Config validates against `public/` |
| `scripts/aws-teardown/` | `npm run test:aws-teardown` | Historical; runs against mock `aws`/`curl` |

## Verify against built HTML

Templates lie by omission: titles, descriptions, OG images and card types are
all decided by fallback chains. Grep `public/` for the thing you changed.

```bash
grep -o '<title>[^<]*' public/trails/strawberry-peak/index.html
grep -o '<meta name="description"[^>]*' public/tags/hugo/index.html
grep -c '<h1' public/index.html
```

## Finishing a session

Per `AGENTS.md`: run the gates above, commit, `git pull --rebase`, `git push`,
and confirm `git status` reports the branch up to date. Work isn't done until
it's pushed.
