# Writing style

The site is one person's voice: Ben Strawbridge, a Los Angeles web consultant
who builds things, hikes, cooks and listens to a lot of music. Write as him
on the site, and as a careful engineer in the repo.

## On the site

### Voice

- **First person, plain and specific.** "I built this because…", not "This
  project was developed to…". Contractions are fine.
- **Practical first, wry second.** The README's register is the target: "Have a
  website that needs a grown-up? An API that refuses to cooperate?" One light
  line per section is plenty. Don't force jokes.
- **Concrete over adjectival.** Name the street, the version, the elevation, the
  pass you need to park. A detail only a local or a practitioner would know is
  worth more than any adjective.
- **Banned filler:** "nestled", "boasts", "vibrant", "stunning", "don't miss",
  "hidden gem", "game-changer", "delve", "in today's fast-paced world", "unlock".
- **Honest about memory and uncertainty.** If a piece is reconstructed from a
  recording or recollection, say so in an italic note (see the 9/11 essay).
- American English. Em dashes appear both spaced and unspaced across the site;
  pick one per page. Curly quotes are fine in prose.

### Shape of a page

1. **Lede** — one or two sentences that say what this is and why it matters.
   It becomes the summary, so it must stand alone.
2. `<!--more-->`
3. **Body** with `##` sections. The page title is the only `<h1>`; never add
   another, and never demote the title.
4. A `description` in front matter: one sentence, 120–160 characters, written
   for a search result, not copied from the lede.

### By section

| Section | Register | Specifics |
| --- | --- | --- |
| Posts | First-person essay or how-to. How-tos show the code (`{{</* highlight */>}}`), then explain it. | Lead with the result, then "How does it work?". Tag generously but reuse tags. |
| Projects | Case study: problem, what was built, stack, outcome, link. | Say what you'd do differently if it's true. |
| Trails | Second-person directions with first-person local knowledge. | Follow the rewrite rules in [walking-tour-guide-spec.md §7](walking-tour-guide-spec.md#7-transcription--narrative-rewrite-rules): lead with place, one local detail per stop, 100–200 words a stop, parking and passes always. |
| Links | **Neutral third person**, 1–2 sentences: what the thing is and why it's useful. | "Anthropic's product page for Claude Code, an agentic coding tool that runs in the terminal or an IDE." No first person, no hype. Tags lowercase-kebab. |
| Recipes | Warm, family-voiced headnote, then the structured recipe. | Ingredients and steps live in front matter for schema.org; the body is story and tips. |
| Listening | Generated. Don't hand-write. | — |
| Consulting | Direct, client-facing, outcomes over buzzwords. | Name real tools (Auth0, Okta, AWS) rather than categories. |

### Images

Every image gets real alt text describing what's in it ("Concert lights coming
up over Dead and Company at the Forum"), not "image" or the filename. Prefer
the theme's `picture` shortcode so Hugo generates responsive sizes.

## Docs, comments and commits

The repo's engineering writing has a consistent house style. Match it.

### Docs (this knowledge base) and long code comments

- **Lead with the rule, then the why.** "Hugo `aliases` are not redirects." then
  the evidence. Readers skim the bold sentence; the paragraph is for the
  sceptic.
- **Evidence beats assertion.** Give the measurement, the date, the version, the
  commit: "ranked at position 6.26 — above the real page at 6.74",
  "verified on Hugo 0.164.0", "until 2026-09". Say how to re-measure.
- **Name the failure mode.** Say what breaks and how you'd notice ("fails
  silently", "breaks every opacity modifier", "the build dies with…").
- **Mark load-bearing details** explicitly ("The `+1` on `$max` is
  load-bearing") and say what not to do ("Do not weaken that check").
- **Distinguish observed from documented** behaviour ("treat it as observed, not
  guaranteed").
- Paths in backticks, repo-relative. Tables for anything with more than two
  parallel facts. No marketing tone, no emoji.
- Comments explain *why this line exists*; point to `docs/` for anything longer
  than a paragraph rather than duplicating it.

### Commit messages

- **Subject:** imperative, sentence case, no trailing period, ≤ ~72 chars, says
  what changed for the site: "Send a 404 event to PostHog from the not-found
  page", "Shadow the theme's _headers; let highlight-github degrade in
  production".
- **Body:** why, what was verified and how (build environment, counts before
  and after), anything deliberately left alone.
- Automated commits keep their prefix: `spotify: sync play data YYYY-MM-DD`.
- One logical change per commit; content changes commit their OG card with them.
