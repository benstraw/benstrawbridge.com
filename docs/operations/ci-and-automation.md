# CI and automation

Cloudflare Workers Builds is the deploy pipeline
([deployment/cloudflare.md](../deployment/cloudflare.md)). GitHub Actions does
everything else:

| Workflow | Trigger | Does | Secrets / vars |
| --- | --- | --- | --- |
| `posthog-deploy-annotation.yml` | `check_run` completed: `Workers Builds: benstrawbridge-com`, success, commit on `main` | Creates a deduplicated PostHog deploy annotation; `continue-on-error` so it can never fail a deploy | `POSTHOG_CI_API_KEY` (secret), `POSTHOG_PROJECT_ID`, optional `POSTHOG_HOST` — [runbook](../runbooks/posthog-deploy-tracking.md) |
| `sync-spotify-data.yml` | Mondays 06:00 UTC; manual | Pulls play data from `benstraw/obsidian-music-garden`, aggregates, commits to `main` | `GARDEN_REPO_TOKEN` — [data/spotify-listening.md](../data/spotify-listening.md) |
| `claude.yml` | `@claude` in an issue, issue comment, PR review or review comment | Runs Claude Code (`anthropics/claude-code-action@v1`) with git-only extra tools | `CLAUDE_CODE_OAUTH_TOKEN` |
| `claude-code-review.yml` | Manual only (`workflow_dispatch`) | Runs the `code-review` plugin against a PR | `CLAUDE_CODE_OAUTH_TOKEN` |

`npm run test:posthog-deploy` statically guards the annotation workflow's
production filter, pinned action SHA, `continue-on-error`, and dedupe prefix.
Run it whenever that file changes.

There is no test or lint workflow. The gates in
[development/checks.md](../development/checks.md) are run before pushing.

## Agent configuration

| File | Purpose |
| --- | --- |
| `AGENTS.md` | Entry point for every coding agent; points here |
| `CLAUDE.md` | `@AGENTS.md` — Claude Code loads AGENTS.md through it |
| `.github/copilot-instructions.md` | Short Copilot brief (content creation, key paths) |
| `.claude/settings.json` | Registers the SessionStart hook; small permission allowlist |
| `.claude/hooks/session-start.sh` | Cloud-session bootstrap — [development/local-and-cloud.md](../development/local-and-cloud.md) |
| `.claude/commands/new-walking-tour.md` | `/new-walking-tour`: interviews the user and builds a `/trails/` page |

`bd` (beads) was removed from this project; there is no `.beads` database.
