# PostHog deploy tracking

Every successful Cloudflare production deploy creates a PostHog project annotation. The marker makes it possible to line up changes in traffic and search performance with the commit that shipped.

**Source of truth:** `.github/workflows/posthog-deploy-annotation.yml`; the static guard is `scripts/posthog-deploy-annotation.test.mjs`.

## How it works

Cloudflare Workers Builds deploys each production commit and reports a completed GitHub check named `Workers Builds: benstrawbridge-com`. The annotation workflow listens for that check, then continues only if it succeeded and GitHub says the commit is in `main`. Preview builds use the same check name but run branch commits, so they are skipped.

The annotation reads:

```
benstrawbridge.com production deploy @ <full SHA> · <short SHA> · <commit subject> · <commit URL>
```

The full SHA is the dedupe key. Re-running the GitHub job or a Cloudflare retry is safe: the official PostHog action finds the existing marker. PostHog runs after Cloudflare has deployed and uses `continue-on-error`; an annotation outage cannot delay or fail production.

## One-time setup

1. In PostHog, switch to the `benstrawbridge.com` project. Create a Personal API Key limited to that project with **Annotation: Write** only. This is a private `phx_…` key — distinct from the public browser `phc_…` project key.
2. In GitHub repository settings, add Actions secret `POSTHOG_CI_API_KEY` containing that personal key.
3. Add Actions variable `POSTHOG_PROJECT_ID` containing the numeric PostHog project ID. `POSTHOG_HOST` is optional and defaults to the US cloud host.
4. Merge a small change to `main`, wait for the successful `Workers Builds: benstrawbridge-com` check, then open the `PostHog deploy annotation` workflow run. It should report the marker content. Re-run that workflow once to confirm deduplication.

Never put `POSTHOG_CI_API_KEY` or a `phx_…` key in Cloudflare, Hugo configuration, source files, or build variables. Cloudflare does not need it.

## Troubleshooting

| Symptom | Meaning / fix |
| --- | --- |
| No annotation workflow run | The Cloudflare check did not have the expected name or did not succeed. Inspect the commit checks first. |
| Run says “not configured” | Add the secret and project-ID variable above, then rerun the workflow. |
| Workflow skips a preview | Expected: only commits reachable from `main` are production. |
| Annotation step fails | Production is already live. Check the key’s project and Annotation: Write permission, then rerun the workflow. |
| Duplicate marker | The stable full-SHA prefix must stay at the beginning of the annotation text for action-level dedupe. |

## Key rotation

Create a replacement least-privilege key, replace the GitHub secret, deploy and verify one marker, then revoke the old key in PostHog. Do not broaden the key’s scope or reuse the browser project key.
