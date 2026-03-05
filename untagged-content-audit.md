# Untagged Content Audit

> Research-only document. No code or content changes have been made.

This audit identifies all content pages on BenStrawbridge.com that have no tags assigned, along with suggested tags for each page.

---

## Summary

| Category | Count |
|---|---|
| Total content files scanned | 137 |
| Published non-section-index pages **with** tags | 53 |
| **Published non-section-index pages without tags** | **13** |
| Draft pages without tags (real content, not test files) | 11 |
| Published section `_index.md` pages without tags | 18 |

---

## Published Pages Without Tags

These are live, published pages that visitors can find but currently have no tags. These should be the first priority to fix.

| Page | File Path | Suggested Tags |
|---|---|---|
| [Analytics](/links/analytics/) | `content/links/analytics/index.md` | `analytics`, `privacy`, `gdpr`, `web-development` |
| [Art](/links/art/) | `content/links/art/index.md` | `art`, `portfolio`, `artists`, `culture` |
| [Blogroll](/links/blogroll/) | `content/links/blogroll/index.md` | `blogroll`, `community`, `indie-web`, `people` |
| [Crypto](/links/crypto/) | `content/links/crypto/index.md` | `crypto`, `bitcoin`, `lightning-network`, `blockchain` |
| [CSS](/links/css/) | `content/links/css/index.md` | `css`, `tailwind`, `web-development`, `frontend` |
| [Fonts & Icons](/links/fonts-icons/) | `content/links/fonts-icons/index.md` | `fonts`, `icons`, `design`, `web-development` |
| [Hugo](/links/hugo/) | `content/links/hugo/index.md` | `hugo`, `static-site-generator`, `web-development`, `jamstack` |
| [Machine Learning and Artificial Intelligence](/links/machine-learning-and-artificial-intelligence/) | `content/links/machine-learning-and-artificial-intelligence/index.md` | `machine-learning`, `ai`, `llm`, `ocr`, `coding-agents` |
| [Mapping](/links/mapping/) | `content/links/mapping/index.md` | `maps`, `leaflet`, `data-visualization`, `geography` |
| [Oblargh](/links/oblargh/) | `content/links/oblargh/index.md` | `miscellaneous`, `curiosities`, `interesting` |
| [The Web](/links/the-web/) | `content/links/the-web/index.md` | `web`, `technology`, `product-management`, `internet` |
| [Tools](/links/tools/) | `content/links/tools/index.md` | `web-development`, `tools`, `productivity`, `performance` |
| [Pick-a-Square Game – Basic Grid](/projects/pick-a-square-game/grid-basic/) | `content/projects/pick-a-square-game/grid-basic/index.md` | `pick-a-squares`, `super-bowl-squares`, `games`, `football` |

**Note:** All 12 links pages above have `tags = [...]` in the frontmatter but it is **commented out** (`# tags = [`). The fix is simply to uncomment those lines and fill in the values.

---

## Draft Pages Without Tags

These pages are not yet published (marked `draft = true`) but will need tags before they go live.

| Page | File Path | Notes | Suggested Tags |
|---|---|---|---|
| [The Steel Woods Live at the Echo](/posts/the-steel-woods-live-at-the-echo/) | `content/posts/the-steel-woods-live-at-the-echo/index.md` | Has `tags = []` explicitly (empty). Already has `categories = ["live music"]` | `live-music`, `americana`, `country-rock`, `los-angeles`, `concert` |
| This Website | `content/projects/this-website/index.md` | About building this site | `personal-website`, `hugo`, `dogfooding`, `affiliate-marketing` |
| Go Bag Essentials | `content/projects/hiking/gear/go-bag-essentials.md` | Hiking/emergency gear list | `hiking`, `gear`, `emergency-prep`, `outdoors` |
| Hugo Related Content Feature | `content/posts/hugo-related-content-feature/index.md` | Hugo how-to, stub | `hugo`, `related-content`, `static-site-generator`, `web-development` |
| Helpful Hugo Things | `content/posts/helpful-hugo-things/index.md` | Hugo tips, stub | `hugo`, `tips`, `static-site-generator`, `web-development` |
| Websites (Portfolio) | `content/portfolio/websites.md` | Career history of websites worked on | `portfolio`, `web-development`, `career` |
| Goals | `content/goals/index.md` | Personal goals (also marked `private = true`) | `personal`, `goals`, `annual-review` |
| Email Links | `content/links/email/index.md` | Email forwarding & newsletter platforms | `email`, `newsletters`, `marketing`, `tools` |
| Services Links | `content/links/services/index.md` | Finance, payments, e-commerce services | `services`, `finance`, `ecommerce`, `tools` |
| Testing Links | `content/links/testing/index.md` | Web testing and accessibility tools | `testing`, `accessibility`, `web-development`, `tools` |
| Hike With Ben – Website | `content/projects/hiking/hike-with-ben/website.md` | Stub for the Hike With Ben sub-project site | `hiking`, `los-angeles`, `dogs`, `hike-with-ben` |

---

## Published Section Index Pages Without Tags

These are `_index.md` files that define Hugo sections/categories. They typically don't display tags the same way regular pages do, so tagging them is a lower priority — but it is still possible and can aid in related-content matching.

| Section | File Path |
|---|---|
| Home | `content/_index.md` |
| Projects | `content/projects/_index.md` |
| Posts | `content/posts/_index.md` |
| Consulting | `content/consulting/_index.md` |
| Fine Print | `content/fineprint/_index.md` |
| Recipes | `content/projects/recipes/_index.md` |
| Hiking | `content/projects/hiking/_index.md` |
| Westchester / Playa Vista / Playa Del Rey Hiking Guide | `content/projects/hiking/westchester-playa-vista-playa-del-rey-hiking-guide/_index.md` |
| Product Marketing | `content/projects/product-marketing/_index.md` |
| Product Catalog | `content/projects/product-marketing/catalog/_index.md` *(has `tags = []`)* |
| Content Adaptors | `content/projects/content-adaptors/_index.md` |
| Spotify Top Artists | `content/projects/content-adaptors/spotify/_index.md` |
| Pick a Square Game | `content/projects/pick-a-square-game/_index.md` |
| Tags index | `content/tags/_index.md` |
| Family Recipes tag page | `content/tags/family-recipes/_index.md` |
| Category: Catalog | `content/categories/catalog/_index.md` |
| Category: Recipes | `content/categories/recipes/_index.md` |
| Category: Hiking | `content/categories/hiking/_index.md` |

---

## Excluded From This Audit

The following were intentionally excluded from the table above as they are test/development scaffolding with no real content:

- All files under `content/test/` and `content/posts/testdeep/` (stub test pages)
- `content/links/_index.md` – **already has tags** (`hugo`, `themes`, `css`, `images`, `blogroll`)
- `content/everything-everywhere/_index.md` – **already has tags** (`everything`, `everywhere`, `all-at-once`)
- All tagged hiking trail pages under `content/projects/hiking/westchester-playa-vista-playa-del-rey-hiking-guide/` – **all already tagged**
- All published posts (`content/posts/`) – **all already tagged**
- All published recipes – **all already have ingredients/tags**

---

## Recommended Next Steps

1. **Quick win:** Uncomment and fill in the `tags` field in all 12 links pages (one-liner change per file).
2. **High value:** Add tags to `content/projects/pick-a-square-game/grid-basic/index.md`.
3. **Before publishing drafts:** Add tags to each draft page listed above before toggling `draft = false`.
4. **Low priority:** Consider whether section `_index.md` pages benefit from tags given the site's related-content configuration.
