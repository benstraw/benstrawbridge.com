# Agent Instructions

`bd` (beads) has been removed from this project. Do not use `bd` commands or assume a `.beads` database exists.

## Deployment context

- Production is a static-assets-only Cloudflare Worker. Cloudflare Workers Builds
  deploys `main`; AWS Amplify is retired and must not be treated as an active
  deployment path.
- Every successful production build should receive the PostHog deploy marker
  described in [`docs/runbooks/posthog-deploy-tracking.md`](docs/runbooks/posthog-deploy-tracking.md).
- For build, preview, redirect, and Cloudflare configuration details, read the
  **Cloudflare deploy** section of [`CLAUDE.md`](CLAUDE.md) before changing
  hosting or deployment behavior.

## Landing the Plane (Session Completion)

**When ending a work session**, you MUST complete ALL steps below. Work is NOT complete until `git push` succeeds.

**MANDATORY WORKFLOW:**

1. **Run quality gates** (if code changed) - Tests, linters, builds
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
