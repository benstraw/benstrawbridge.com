# Ryder issue draft: order and cap the footer taxonomy lists

Ready to paste into <https://github.com/arts-link/ryder/issues/new>.

This could not be filed from the session that wrote it: `add_repo` refuses
cross-owner adds once a session is scoped to one owner, so `arts-link/ryder` was
unreachable from a `benstraw/benstrawbridge.com` session. Filing it needs a
session started with `arts-link/ryder` as the initial source.

Once the issue exists, replace this file with a link to it, or delete it — the
reasoning it carries is duplicated in the "Forked theme partials" section of
`CLAUDE.md`, which is the copy that needs to stay accurate.

Scope note: an earlier draft of this issue also proposed capping
`taxonomy-cloud.html` behind a collapse. That was tried on benstrawbridge.com and
**reverted** — sorting a tag cloud by count replaces the interspersed big-and-
small chips that make a cloud legible with a monotonic size ramp. The cloud is
fine as the theme ships it. This issue is footer-only.

---

**Title:** `footer taxonomy lists are alphabetical and uncapped, which doesn't survive a machine-generated taxonomy`

**Labels:** `enhancement`, `breaking-change-minor`

---

## Body

### Problem

`layouts/partials/utils/taxonomy-string.html` filters each configured group by
`minCount` and then ranges the taxonomy **map**. Ranging the map means
alphabetical order, and there is no cap. That is fine for a hand-curated tag
list; it falls apart for a taxonomy generated from an API.

On benstrawbridge.com the `musical-genres` taxonomy is built from Spotify data
via a content adaptor. Measured shape:

- **512 terms** across 854 artist pages, 2427 assignments
- **243 terms (47%) apply to exactly one artist** — Spotify's hyper-specific tail
- top counts: `jazz` 97, `hard bop` 59, `bebop` 58, `americana` 51,
  `classical piano` 42

Two consequences on Ryder v0.4.1:

1. The footer ships **~78 taxonomy links on every page**, ordered so that
   `acid jazz` (7 artists) precedes `jazz` (97). The most useful links are not
   where a reader looks first.
2. The list is **unbounded**. It grows every time the Spotify sync adds an
   artist, with nothing in config to stop it.

`minCount` is the only lever, and it's a blunt one: it can't express "show the
terms that matter" without also cutting mid-tail terms. It also interacts
confusingly with any cap — see below.

### Proposal

Order by page count, and add a `maxTerms` cap per group:

```toml
[[params.footer.taxonomies]]
  name     = "musical-genres"
  title    = "Musical Genres"
  minCount = 10   # existing floor, unchanged semantics
  maxTerms = 39   # new: cap the group after the floor
```

Iterate `(index site.Taxonomies $taxonomy).ByCount` instead of the map, apply
`minCount` as a floor, then `first $maxTerms` on the result. `maxTerms` unset =
today's behavior for that group.

### Two things worth documenting alongside it

**`minCount` decides the eligible pool, not `maxTerms`.** Because the floor
applies first, a cap above the pool size is silently inert. On this site:

| `minCount` | genres eligible | | `minCount` | tags eligible |
|---|---|---|---|---|
| 12 | 55 | | 6 | 24 |
| 10 | 67 | | 5 | 33 |
| 8 | 82 | | 4 | 43 |

Raising `maxTerms` without lowering `minCount` frequently changes nothing, which
is a confusing first experience. Worth a line in the README.

**How does `.ByCount` order terms with equal counts?** I could not find this
documented. It matters here: a `maxTerms` that slices through a group of tied
terms shows some and hides others, and if the tie order isn't stable the footer
reshuffles between builds. On this site nine tags tie at 5 uses and two genres
tie at 14, so the caps were deliberately set to land on clean count boundaries
(41 and 33) to sidestep the question. If `.ByCount` does tie-break
deterministically — by name, say — documenting that would let sites pick caps
freely. If it doesn't, `maxTerms` may want to extend through a tie rather than
cut it.

### Is this breaking?

**Not in the config sense.** `maxTerms` defaults to no cap and `minCount` keeps
its `default 1`, so a site that upgrades and changes nothing keeps its current
term set.

**But two changes land on every site regardless of config**, so this wants a
minor release with notes rather than a patch:

1. **Link order flips** from alphabetical to by-count. That's the point of the
   change — gating it would preserve a behavior nobody wants — but it will break
   any downstream snapshot or order-dependent assertion.
2. **`href` form changes** if the term URL is built with `relURL` (or resolved
   through the term page) instead of the current
   `printf "%s%s/%s" $baseURL $taxonomy ($name | urlize)`.
   Absolute-without-trailing-slash becomes relative-with-trailing-slash. This is
   strictly a **fix for multilingual sites** — the current hand-built URL ignores
   language prefixes and points at the wrong page — but it is a changed URL
   string everywhere, and it matters to anyone using `canonifyURLs` or an unusual
   `baseURL`. Reasonable to split into its own PR.

One thing **not** to add: a "see all N →" link at the end of a capped group. It
was in the first implementation here and removed — the group heading is already
an anchor to the same taxonomy page, chevron and all, so the extra link is pure
duplication a few pixels below.

### Prior art

Implemented as a site-level fork of the partial on benstrawbridge.com, verified
against a development build: footer down to 40 links from 78 (24 genres + 16
tags), `jazz` leading the genre group, and both caps landing on a clean count
boundary so no tied group was sliced.

Worth noting for the upstream design: `.ByCount` appears to tie-break
alphabetically (observed on Hugo 0.164.0 — the 15-artist genres emit as `memphis
soul, noise rock, rock, southern soul`), so a cap through a tie is at least
stable across builds. It is still arbitrary to a reader, which is why the caps
here are chosen to land between counts. If that tie-break is intentional it is
worth documenting; if it is incidental, a cap-aware implementation should not
rely on it.

### Companion request: a floor for `taxonomy-cloud.html`

The same "every term, no exceptions" assumption bites the tag cloud, and it is
now a second site-level fork on benstrawbridge.com. `/musical-genres/` was
rendering all 512 chips including the 243 one-artist genres, which crowded out
the genres that carry weight.

A per-taxonomy floor would retire that fork too:

```toml
[params.taxonomyCloud.minCount]
  "musical-genres" = 2   # absent or 1 = today's behaviour, every term
```

Two things the implementation should get right, both learned the hard way here:

- **Keep ranging the taxonomy map.** Its alphabetical order is what keeps big and
  small chips interspersed, and that scattering is what makes a cloud legible. A
  first attempt sorted by count and produced a monotonic size ramp — a sorted
  list with variable type. Use `.ByCount` only to find the displayed range.
- **Compute the font scale over the terms that survive the filter.** Anchoring
  `$min` to the unfiltered minimum while showing only 2-and-up strands the bottom
  of the range on chips that are never drawn, pushing everything up and
  flattening the size variety. Recomputing also removes the current partial's
  latent divide-by-zero (`$spread` is 0 on a single-term taxonomy) and makes the
  existing `+1` on `$max` do real work.

Filtering the cloud does not orphan anything, which is worth stating in the docs
for the option: Hugo still builds every term page, and sites typically link terms
from the pages that carry them.

While in that file: line 28's linear `$currentFontSize` is immediately shadowed
by the log-weighted assignment on line 30, so it is dead.

Note that 72-vs-78 was not a size win at the caps this started with — the value
delivered is the ordering and the fixed ceiling as the library grows. A site
wanting a genuinely shorter footer sets lower caps (this one now runs 24 + 16 =
40); the point is that the config makes it possible at all.

Happy to open a PR against Ryder that retires both forks.
