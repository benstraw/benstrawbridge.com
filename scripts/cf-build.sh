#!/usr/bin/env bash
#
# Build command for Cloudflare Workers Builds: `npm run cf:build`.
#
# Workers Builds clones the repo, installs npm dependencies from the lockfile,
# runs this, then `npx wrangler deploy` (production) or `npx wrangler versions
# upload` (preview) ships ./public as static assets per wrangler.jsonc.
#
# Production is the `main` branch, or any run outside Workers Builds. Every other
# branch is a preview, which differs from production in three ways:
#   - PUBLIC_POSTHOG_KEY is cleared, so preview traffic never lands in analytics.
#   - baseURL is root-relative. Hugo emits absolute www URLs for assets, and the
#     CSP meta tag's 'self' rejects those on a *.workers.dev preview host.
#   - public/_headers gains X-Robots-Tag: noindex for every path.
#
set -euo pipefail

cd "$(dirname "$0")/.."

# Workers Builds sets WORKERS_CI_BRANCH. Unset means a local run: treat it as
# production so the output matches what ships.
PRODUCTION_BRANCH="main"
BRANCH="${WORKERS_CI_BRANCH:-$PRODUCTION_BRANCH}"

# 1. The Ryder theme. A no-op if the clone already fetched the submodule.
git submodule update --init --recursive

# 2. Hugo extended. Cloudflare installs it when HUGO_VERSION is set in the build
#    variables, and that value carries "extended" in it, so only the number is
#    extracted here. The download is a fallback for when the variable is
#    missing or the image did not honour it.
HUGO_WANT="$(grep -oE '[0-9]+\.[0-9]+\.[0-9]+' <<<"${HUGO_VERSION:-}" | head -n1 || true)"
HUGO_WANT="${HUGO_WANT:-0.164.0}"
HUGO_BIN="hugo"
if ! hugo version 2>/dev/null | grep -q "extended"; then
  cache="node_modules/.cache/hugo/${HUGO_WANT}"
  if [ ! -x "${cache}/hugo" ]; then
    echo "cf-build: Hugo extended not on PATH; downloading v${HUGO_WANT}"
    mkdir -p "$cache"
    curl -fsSL --retry 3 --retry-delay 2 \
      "https://github.com/gohugoio/hugo/releases/download/v${HUGO_WANT}/hugo_extended_${HUGO_WANT}_linux-amd64.tar.gz" \
      | tar -xz -C "$cache" hugo
  fi
  HUGO_BIN="${cache}/hugo"
fi
"$HUGO_BIN" version

# 3. Build.
if [ "$BRANCH" = "$PRODUCTION_BRANCH" ]; then
  echo "cf-build: production build (branch ${BRANCH})"
  "$HUGO_BIN" --gc --minify --cleanDestinationDir
else
  echo "cf-build: preview build (branch ${BRANCH})"
  PUBLIC_POSTHOG_KEY="" "$HUGO_BIN" --gc --minify --cleanDestinationDir \
    --environment "${HUGO_ENVIRONMENT:-production}" \
    --baseURL "${CF_PREVIEW_BASEURL:-/}"
  printf '\n/*\n  X-Robots-Tag: noindex\n' >>public/_headers
fi
