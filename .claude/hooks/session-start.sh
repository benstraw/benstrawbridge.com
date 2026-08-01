#!/bin/bash
#
# SessionStart hook for Claude Code on the web.
#
# A fresh remote container clones this repo with an uninitialized Ryder
# submodule, no Hugo binary, and no node_modules — so nothing builds and no
# check runs. This restores all four things the site needs. It is a no-op on a
# local machine, which has its own setup.
#
set -euo pipefail

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

cd "${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel)}"

# Keep at or above config/_default/module.toml's hugoVersion.min (0.146.0).
# Checksum is for the linux-amd64 extended tarball of this exact version.
HUGO_VERSION="0.164.0"
HUGO_SHA256="fea17b8c076f950bb2e9f9486667bdaa29422883888d509d63931c73e8a9b3a4"

# 1. The Ryder theme. Without this themes/ryder is an empty directory and every
#    layout, partial and design token resolves to nothing.
git submodule update --init --recursive

# 2. config/_default sets `theme = 'ryder-dev'`, which is gitignored because it
#    is normally a local working checkout of the theme. `hugo server` runs in
#    the development environment and would fail outright without it, so point
#    it at the submodule. Production (config/production sets `theme = "ryder"`)
#    does not use this path and is unaffected.
if [ ! -e themes/ryder-dev ]; then
  ln -s ryder themes/ryder-dev
fi

# 3. Hugo extended. Not in the base image, and the plain (non-extended) build
#    will not satisfy module.toml.
if ! hugo version 2>/dev/null | grep -q "v${HUGO_VERSION}.*extended"; then
  arch="$(uname -m)"
  if [ "$arch" != "x86_64" ]; then
    echo "session-start: no pinned Hugo checksum for $arch; add one to this hook." >&2
    exit 1
  fi

  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT

  curl -fsSL --retry 3 --retry-delay 2 -o "$tmp/hugo.tar.gz" \
    "https://github.com/gohugoio/hugo/releases/download/v${HUGO_VERSION}/hugo_extended_${HUGO_VERSION}_linux-amd64.tar.gz"
  echo "${HUGO_SHA256}  $tmp/hugo.tar.gz" | sha256sum -c -
  tar -xzf "$tmp/hugo.tar.gz" -C "$tmp" hugo
  install -m 0755 "$tmp/hugo" /usr/local/bin/hugo
fi

# 4. npm deps: Tailwind and PostCSS drive the CSS pipeline, Font Awesome backs
#    `npm run test:fa-icons`. `install` rather than `ci` so the cached container
#    state is reused on later sessions.
npm install --no-audit --no-fund

hugo version
