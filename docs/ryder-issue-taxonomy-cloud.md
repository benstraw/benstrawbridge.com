# Ryder issue draft: cap and order the taxonomy cloud + footer taxonomy lists

Ready to paste into <https://github.com/arts-link/ryder/issues/new>.

This could not be filed from the session that wrote it: `add_repo` refuses
cross-owner adds once a session is scoped to one owner, so `arts-link/ryder` was
unreachable from a `benstraw/benstrawbridge.com` session. Filing it needs a
session started with `arts-link/ryder` as the initial source.

Once the issue exists, replace this file with a link to it, or delete it — the
reasoning it carries is duplicated in the "Forked theme partials" section of
`CLAUDE.md`, which is the copy that needs to stay accurate.

---

**Title:** `taxonomy-cloud and footer taxonomy lists don't survive a machine-generated taxonomy`

**Labels:** `enhancement`, `breaking-change-minor`

---

## Body

### Problem

`layouts/partials/taxonomy-cloud.html` and
`layouts/partials/utils/taxonomy-string.html` both render **every** term in a
taxonomy, in alphabetical order. That is fine for a hand-curated tag list. It
falls apart for a taxonomy generated from an API.

On benstrawbridge.com the `musical-genres` taxonomy is built from Spotify data
via a content adaptor. Current shape:

- **511 terms**, across 854 artist pages
- **47% of terms apply to exactly one artist** (Spotify's hyper-specific genre tail)
- top counts: `jazz` 97, `hard bop` 59, `bebop` 58, `americana` 51, `classical piano` 42

Two consequences on Ryder v0.4.1:

1. `/musical-genres/` renders **all 511 chips at up to 3.8rem**. The page is
   enormous and `jazz` (97 artists) is visually lost among hundreds of one-offs.
2. The footer ships **~78 taxonomy links on every page**. `taxonomy-string.html`
   applies only a `minCount` floor and then ranges the taxonomy **map**, so
   ordering is alphabetical and the list is uncapped — `acid jazz` (7 artists)
   precedes `jazz` (97), and the list grows without bound as the data grows.

Alphabetical ordering is the root issue in both places: it means `minCount` is
the only lever, and `minCount` is a blunt one — it can't express "show me the
terms that matter" without also hiding mid-tail terms on smaller taxonomies.

### Proposal

Order by page count in both partials, and make what's shown config-driven.

```toml
[params.taxonomyCloud]
  topPercent = 10   # share of terms sized and shown expanded; default 100
  minShown   = 20   # floor, so a small taxonomy isn't cut to a few chips

[[params.footer.taxonomies]]
  name     = "tags"
  title    = "Tags"
  minCount = 6      # existing floor, unchanged
  maxTerms = 15      # new: cap the group after the floor
```

In the cloud, the top `topPercent` of terms are sized and shown; the remainder
goes into an Alpine collapse, alphabetical, at one uniform size. **All terms
stay in the HTML**, so the long tail is still crawlable and findable with
Ctrl-F — it's progressive disclosure, not truncation.

Measured result on benstrawbridge.com at `topPercent = 10`, `maxTerms = 15`:

| | before | after |
|---|---|---|
| `/musical-genres/` sized chips | 511 | 52 (459 collapsed) |
| `/tags/` sized chips | 262 | 27 (235 collapsed) |
| footer taxonomy links per page | 78 | 32 |

### Two implementation details worth preserving

**The font scale must be computed over the displayed subset, not the whole
taxonomy.** Reusing the full-set minimum (1 page) against a filtered head
pushes every chip toward the bottom of the range — you get a trimmed cloud
that is also visually flat. Recompute `$min`/`$max` from the head.

**The `+1` on `$max` turns out to be load-bearing.** It is what keeps
`log($max) - log($min)` non-zero when every shown term has the same count,
which a filtered head makes much more likely than an unfiltered one. Worth a
comment so it doesn't get "cleaned up" later.

Also: the dead linear `$currentFontSize` at line 28 of the current partial is
immediately shadowed by the log-weighted assignment at line 30. Harmless, but
confusing to read.

### CSP-Alpine constraint

The collapse toggle has to be a named `Alpine.data()` component registered in
`assets/js/main.js`, not an inline `expanded = !expanded`. The theme bundles
`@alpinejs/csp`, so an inline assignment renders fine, never fires, and logs
nothing — exactly the failure mode documented in the header of
`assets/js/cspLint.js`. Something like:

```js
Alpine.data('taxonomyTail', () => ({
  expanded: false,
  toggle() { this.expanded = !this.expanded },
}))
```

`x-cloak` already has a rule in the theme CSS, so the tail stays hidden before
hydration.

### Is this breaking?

**Not in the config sense.** `topPercent` defaults to `100`, which makes
`shown = ceil(total × 1.0) = total`, an empty tail, and no collapse markup.
`maxTerms` defaults to `0` (no cap) and `minCount` keeps its `default 1`. A
site that upgrades and changes nothing gets no collapse, no truncation, and
identical font sizes.

**But three changes land on every site regardless of config**, and should go in
a minor release with notes rather than a patch:

1. **Chip order flips** from alphabetical to by-count. This is the point of the
   change, so gating it would preserve a behavior nobody wants — but it will
   break any downstream snapshot or order-dependent assertion.
2. **`href` form changes** if the term URL is resolved through the term page's
   `.RelPermalink` instead of `printf "%s%s/%s" $baseURL $taxonomy ($name | urlize)`.
   Absolute-without-trailing-slash becomes relative-with-trailing-slash. This is
   strictly a **fix for multilingual sites** — the current hand-built URL ignores
   language prefixes and points at the wrong page — but it is still a changed URL
   string everywhere, and it matters to anyone using `canonifyURLs` or an unusual
   `baseURL`.
3. **A new wrapper element** around the sized head inside `.tagcloud` breaks any
   downstream CSS using a direct-child selector such as `.tagcloud > a`.

One further change is worth gating explicitly: an **"all N →" link** at the end
of a capped footer group is useful, but if it renders whenever
`len(shown) < len(terms)` then a site that sets only `minCount` — the pattern the
README documents — gets a new visible element without touching its config. Put
it behind its own param, or only render it when `maxTerms` is actually set.

### Prior art

Implemented as site-level forks of both partials on benstrawbridge.com and
verified against a development build: toggle expands and collapses on
`/musical-genres/` and `/tags/`, `aria-expanded` tracks state, `cspLint` silent.
Chip markup was factored into a shared `utils/taxonomy-chip.html` so the head
and tail loops don't each duplicate the gradient and per-term `twClasses`
resolution — probably worth doing upstream too.

Happy to open a PR against Ryder that retires the fork.
