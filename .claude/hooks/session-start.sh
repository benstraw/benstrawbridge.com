#!/bin/bash
# SessionStart hook: bring a fresh container up to a buildable state.
#
# A clone in Claude Code on the web starts with an empty themes/ryder and no
# node_modules, so Hugo cannot build until both are in place. Everything here is
# idempotent — the container image is cached after the hook completes, so repeat
# sessions skip straight past the installs.
set -euo pipefail

# Local checkouts manage their own theme working copy and node_modules; only the
# remote containers need this.
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

cd "${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel)}"

# The Ryder theme is a git submodule and a fresh clone leaves it unpopulated.
if [ ! -d themes/ryder/layouts ]; then
  echo "session-start: initializing themes/ryder submodule"
  git submodule update --init --recursive
fi

# config/_default/hugo.toml sets theme = 'ryder-dev', which expects a local theme
# working copy alongside the submodule; only config/production/hugo.toml points at
# 'ryder'. Without this link every non-production build (including `hugo server`)
# fails with `module "ryder-dev" not found`. /themes/ryder-dev is gitignored, so
# the link stays out of the repo.
if [ ! -e themes/ryder-dev ]; then
  echo "session-start: linking themes/ryder-dev -> ryder"
  ln -s ryder themes/ryder-dev
fi

if [ ! -d node_modules ]; then
  echo "session-start: installing npm dependencies"
  npm install --no-audit --no-fund
fi

# Hugo 0.164 runs PostCSS under Node's permission model, scoped by
# security.node.permissions.allowread (default ['.']). autoprefixer — which
# postcss.config.js loads for production builds — pulls in browserslist, which
# walks parent directories looking for config and browserslist-stats.json and
# dies on ERR_ACCESS_DENIED above the project root. Widening the read scope for
# the session restores pre-0.164 behavior without touching the site config or
# affecting deploys.
if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
  echo "export HUGO_SECURITY_NODE_PERMISSIONS_ALLOWREAD='/'" >> "$CLAUDE_ENV_FILE"
fi

echo "session-start: ready"
