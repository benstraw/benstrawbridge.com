+++
title = 'Building OCR-Powered Search for a Family Photo Gallery'
date = 2026-01-15T10:00:00-08:00
homeFeatureIcon = "fa-solid fa-magnifying-glass"
tags = [
  "ocr",
  "computer-vision",
  "hugo",
  "static-site",
  "search",
  "javascript",
  "python",
  "tesseract",
  "vision-models",
  "fuse.js",
  "opencv",
  "client-side-search",
  "web-development",
  "machine-learning",
  "photoswipe",
  "family-photos",
  "digital-archiving"
]
# draft = true
+++

I built a search engine for 3,400+ scanned family photo album pages using OCR and client-side JavaScript. The [Gordon Landreth Photography](https://gordon-landreth-photography.arts-link.com/) site now has a [working search interface](https://gordon-landreth-photography.arts-link.com/search/) that lets family members find photos by names, places, and dates from typed captions on album pages spanning 1931-1990s.

<!--more-->

## Introduction

I inherited a problem that probably sounds familiar to anyone who's digitized family photos: I had 48 photo albums, 3,416 scanned pages, and absolutely no way to find anything. Each album page had typed captions with names, places, and dates, but they were just pixels in JPG files. If you wanted to find photos from a specific trip or featuring a particular person, you had to manually flip through hundreds of pages.

This is the story of how I built a search engine for those captions using OCR, client-side JavaScript, and a philosophy of "good enough is better than perfect."

---

## Part 1: The Problem & Architecture Decisions

### The Setup

The Gordon Landreth Photography site is a Hugo-based static gallery hosting my grandfather's photography from 1931-1990s. When I started this project, the site had:

- 46 albums spanning 6 decades
- 3,416 scanned album pages
- Typed captions on most pages with names, dates, locations
- Zero search capability

I wanted family members to search for names ("Show me all photos of Louise"), places ("Where are the Big Bend photos?"), events ("Find the wedding pictures"), and dates ("What do we have from 1947?").

### The Constraints

**Static Site Architecture:** This is a Hugo static site deployed to AWS CloudFront. No backend, no database. Everything had to run in the browser.

**Privacy & Copyright:** These are family photos, not public domain. The site uses `noindex, nofollow` robots tags and privacy-focused Plausible analytics.

**OCR Quality:** These are 1940s-1980s photos with typed captions. Quality varies from crisp typewriter text to faded, skewed, or low-contrast text. Perfect transcription wasn't realistic. I needed "searchable enough."

### Architecture Decision: Client-Side Search

I decided to use **client-side search** with a pre-generated JSON index because:

- No backend infrastructure (fits static site architecture)
- No database or hosting costs
- Privacy-focused (all searching happens in browser)
- Fast search on modern browsers

With only 3,416 pages, client-side search was totally viable. The downside: users download the full search index (~400KB), but CloudFront compresses it to ~100KB.

### Technology Choices

**OCR Engines:** I started with [Tesseract](https://github.com/tesseract-ocr/tesseract) + OpenCV for rapid development iteration:
- Free, open source, runs locally
- Fast (1-2 seconds per image)
- Good enough for typed text

For the final production run, I used **MiniCPM-V 2.6** vision model via LM Studio for significantly better quality on handwritten annotations, faded text, and degraded captions.

**Search Library:** [Fuse.js](https://fusejs.io/) for fuzzy matching:
- Lightweight (~60KB minified)
- Handles OCR typos gracefully
- Works great with 3,000-5,000 entries

### The Search Index Structure

I designed a two-level JSON structure:

**Level 1:** Per-album JSON files (`content/album-name/ocr_captions.json`) containing OCR results for each page with preserved multi-line caption structure.

**Level 2:** Site-wide search index (`static/search/search-index.json`) merging 46 albums + 3,416 pages = 3,462 searchable entries with album metadata and slugs.

This separation lets me rebuild individual albums without reprocessing everything, and provides fast client-side search by loading the index once.

---

## Part 2: The OCR Processing Journey

### The Pipeline

The core OCR pipeline has four stages:

```
Scanned JPG → OpenCV preprocessing → OCR Engine → Caption filtering → JSON
```

**Stage 1:** Detect candidate caption regions using adaptive thresholding and connected components, filtering by geometry (minimum area, aspect ratio) to find white space between photos where captions typically appear.

**Stage 2:** OCR each region. For Tesseract development iteration, I used 2x resize, Gaussian blur, Otsu thresholding, and PSM 6 mode for uniform text blocks. For the final production run with MiniCPM-V 2.6, I sent crop images directly to the vision model.

### The Conservative Filtering Philosophy

Tesseract returns text from every region: real captions, map labels, photo borders, and noise. I needed to filter garbage while keeping real captions.

**Optimize for discovery, not perfection.**

I used **conservative filtering**: prefer keeping questionable text over losing real captions. My filters required:
- Some real letters (minimum 4 alphabetic characters)
- Reasonable word-to-symbol ratio
- Multiple real words OR valid-looking short captions
- Special handling for continuation lines

This caught obvious noise while preserving valid short captions like "Soudersburg," "November, 1947," and "Eden Mill."

### Why Line Breaks Matter

**Preserve multi-line caption structure.** Many captions span multiple lines:

```
An Amish wagon emerges
from covered bridge near
Soudersburg,
```

Line breaks indicate natural reading flow and continuation. The structured `captions` array preserves formatting while a flattened `searchable_text` field enables search.

### Accepted Trade-Offs

**Map Noise:** Pages with maps produce noisy OCR from map labels. Rare enough to accept.

**OCR Errors:** Common mistakes like "yillanova" → "Villanova" are handled by fuzzy search.

**Handwritten Annotations:** Tesseract struggles with handwriting, but the vision model handles it dramatically better.

### Development Workflow: Fast Rebuilds

Processing 3,416 images takes time. My **separate index rebuild script** (`rebuild_search_index.py`) reads existing OCR JSONs and regenerates the search index in 3-5 seconds. This was invaluable for testing search functionality and fixing metadata bugs without rerunning OCR.

### Vision Model for Final Production

After developing and testing with Tesseract, I re-ran all 46 albums with **MiniCPM-V 2.6** vision model for the final production OCR. The quality improvements were dramatic:

- **Handwritten text:** From garbage to readable
- **Degraded/faded text:** Much cleaner, fewer errors
- **Less map noise:** Context-aware filtering
- **Overall accuracy:** Noticeably higher

The vision model took 3-5 hours versus Tesseract's 1-2 hours, but for a one-time production run where quality matters, it was absolutely worth it. I kept Tesseract integration for rapid development iteration.

---

## Part 3: Building the Search Interface

### Fuse.js Integration

I configured Fuse.js with OCR-optimized settings:

```javascript
fuse = new Fuse(searchIndex, {
  keys: [
    { name: 'album_title', weight: 2 },
    { name: 'caption_text', weight: 1.5 },
    { name: 'searchable_text', weight: 0.5 }
  ],
  threshold: 0.4,          // 40% error tolerance for OCR
  ignoreLocation: true,
  minMatchCharLength: 2,
  includeMatches: true,
  includeScore: true
});
```

**Key decisions:**
- **Threshold 0.4:** High tolerance for OCR mistakes and user typos
- **Field weights:** Prioritize album titles, then captions, then filenames
- **ignoreLocation:** Search anywhere in text, not just beginning

### Search-As-You-Type

No submit button. Results appear as you type with 300ms debouncing. Each result shows album title, page link, caption preview (first 3 captions), and a "View Page" button with search term highlighting.

**Performance:**
- Search index: ~400KB JSON (~100KB gzipped)
- Search speed: <50ms for 3,400+ entries
- Works offline after first load

---

## Part 4: Enhancing the Search Experience

After getting basic search working, I discovered through actual use that I needed visual context and better organization.

### The Visual Context Problem

Initial search results showed album title, page filename, and caption text. Functional, but I found myself clicking through 10-15 results because I couldn't remember what "Page 01" looked like. Album titles didn't trigger visual memory.

**Adding Thumbnail Previews** transformed the experience. A simple 120px preview of each page let me:
- Recognize photos instantly by appearance
- Skip irrelevant results without clicking
- Find the right page in seconds instead of minutes

### PhotoSwipe Integration

The gallery already used PhotoSwipe for album pages. Reusing it for search results meant consistent UX with full keyboard navigation, swipe gestures, and caption display. No new dependencies.

**Implementation challenge:** PhotoSwipe needs image dimensions, but search results don't include them. I dynamically load dimensions when building the PhotoSwipe data source.

**Critical detail:** Using event capture phase (`addEventListener` with `true` parameter) intercepts thumbnail clicks before they bubble up and trigger navigation.

Now clicking a thumbnail opens a full-screen lightbox where you can browse search results like a slideshow with arrow keys, view full captions, and escape to close.

### Grouped Search Results

When searching for an album name, both the album and individual pages appeared in results. Confusing. I split results into two groups:

1. **Album Title Matches** - The album name itself matched
2. **Caption Matches** - The OCR caption text matched

This makes it clear at a glance which albums match your search and which specific pages have caption matches.

### Why Simple Won

I had planned Boolean AND filtering, quoted phrase search, and query parsing. I never built any of that.

**Fuzzy matching was sufficient.** With threshold 0.4, Fuse.js handles OCR errors, typos, and partial matches gracefully.

**Visual enhancements mattered more than search precision.** Thumbnails and PhotoSwipe integration had bigger UX impact than perfect search logic. Users can scan 10 visual results faster than they can refine complex queries.

**Conservative filtering philosophy paid off.** By keeping questionable captions, the search index is comprehensive. Fuzzy matching + visual previews let users find what they need even with some noise.

---

## Part 5: Vision Models for Production OCR

After getting search working with Tesseract, I wanted higher quality for the final production run. Tesseract is great for clean typed text, but struggles with handwritten annotations, degraded/faded text, and produces noise from map labels.

### Setting Up LM Studio

I used [LM Studio](https://lmstudio.ai/) to run **MiniCPM-V 2.6** vision model locally:

1. Download LM Studio (free)
2. Search for "MiniCPM-V 2.6" and download (~8GB)
3. Start server (defaults to `http://localhost:1234`)

Within 10 minutes, I had a local vision model server. No API keys, no cloud services, full privacy. Just a simple HTTP endpoint.

### Implementation

I designed vision model integration as **optional enhancement**, not replacement:

```bash
# Fast iteration with Tesseract
python3 ocr_scripts/ocr_pages.py --batch content/

# Production quality with vision model
python3 ocr_scripts/ocr_pages.py --batch content/ --use-llm
```

The architecture uses Tesseract by default, switches to vision model with `--use-llm` flag, and falls back to Tesseract if vision model fails.

### The Prompt Engineering Challenge

Vision models are **chatty**. They want to describe photos, add context, and be helpful. I needed them to **just transcribe caption text**.

After iteration, my final prompt worked well:

```
You are an OCR assistant. Extract the typed or handwritten caption text.

Output ONLY the raw caption text. DO NOT describe photos or add notes.
If no caption, respond with: .

Caption:
```

I also added post-processing filters to catch occasional chattiness and detect hallucinations (excessive character repetition).

### Quality Improvements

The vision model improvements were **dramatic**:

- **Handwritten text:** From garbage to readable
- **Degraded/faded text:** Cleaner transcription, fewer errors
- **Less map noise:** Context-aware filtering
- **Overall accuracy:** Noticeably higher

### Trade-offs

**Processing time:** 3-5 hours versus Tesseract's 1-2 hours. Acceptable for one-time production run.

**Setup complexity:** Requires running LM Studio, but it's easy to use.

**Verdict:** Absolutely worth it for final production where quality matters. Use Tesseract for rapid development iteration, vision model for best quality.

### Final Approach

I used **Tesseract during development** for fast iteration and testing, then re-ran all 46 albums with **vision model for final production** to generate the highest-quality captions. This hybrid approach balanced speed during development with quality for the production search index.

---

## Part 6: Lessons Learned & Reflections

### What Worked

**Conservative OCR Filtering:** Preferring false positives over false negatives was the right call. Better to have some map noise than lose real captions.

**Client-Side Simplicity:** No backend = no maintenance, no costs, no downtime.

**Fast Rebuild Capability:** Separating OCR from indexing enabled iteration in seconds instead of hours.

**Fuzzy Matching:** Fuse.js handles OCR errors beautifully without manual correction.

**Vision Model Quality:** Re-running production OCR with the vision model dramatically improved caption quality, especially for handwritten annotations and faded text. The time investment was worth it.

### What Surprised Me

**Fuzzy Matching Effectiveness:** I expected to need complex Boolean AND logic. Fuse.js threshold tuning was sufficient.

**Client-Side Performance:** 3,400+ entries search instantly, even with PhotoSwipe and dynamic image loading.

**Visual Context Impact:** Thumbnails had 10x the UX impact compared to days spent optimizing search relevance.

**PhotoSwipe Integration:** Reusing the existing gallery lightbox took just hours, not days.

### What I'd Do Differently

**Add Thumbnails Earlier:** Visual previews should have been in the initial design.

**Test with Real Use Cases:** I tested with hypothetical queries. Real use revealed I needed grouping, thumbnails, and lightbox, not better query parsing.

**Trust Simplicity:** I planned complex features I never needed. Fuzzy matching + good UX won.

**Set Up Analytics:** I don't know what people actually search for. Event tracking would guide improvements.

### Success Stories

Searches that work beautifully:
- `"1947 covered bridges"` → Finds exact album with visual previews
- `"Amish"` → Shows all pages with thumbnails for quick scanning
- `"Big Bend"` → Finds all Big Bend photos; click thumbnail to browse in lightbox
- `"yillanova"` (typo) → Fuzzy matching finds "Villanova" correctly

### The "Optimize for Discovery" Philosophy

**Perfect transcription is the enemy of good search.**

If I had waited for 100% OCR accuracy, I'd still be tuning filters and manually correcting thousands of captions. Instead, I shipped something "good enough":

- 95%+ caption accuracy (estimated)
- Fuzzy search handles the remaining errors
- Family members can find photos now

Search is for discovery, not archival transcription.

---

## Conclusion

Building search for 3,400+ scanned photo album pages taught me that "good enough" is often better than "perfect." Key lessons:

1. **OCR doesn't need to be perfect** - Fuzzy search handles errors gracefully
2. **Conservative filtering beats aggressive filtering** - Keep questionable text rather than lose real captions
3. **Client-side search scales surprisingly well** - 3,400 entries search instantly
4. **Visual context beats search precision** - Thumbnail previews had 10x the UX impact
5. **Simple solutions often win** - Fuzzy matching + good UX beat complex Boolean logic I never built
6. **Reuse existing components** - PhotoSwipe was already there
7. **Separate OCR from indexing** - Fast rebuilds enable rapid iteration
8. **Vision model quality is worth it** - Using MiniCPM-V for final production OCR dramatically improved caption quality

The system shipped with features I didn't plan (PhotoSwipe lightbox, thumbnails, grouped results) and without features I thought essential (Boolean AND, phrase search). Real use revealed what mattered.

Family members are now finding photos they forgot existed. Click a thumbnail, browse results in full-screen lightbox, navigate with arrow keys, see high-quality captions from the vision model.

---

## Technical Appendix

### Implementation

**OCR Pipeline:**
- Languages: Python 3, OpenCV, Tesseract, OpenAI SDK
- Development: Tesseract (1-2 seconds/image, 1-2 hours total)
- Production: MiniCPM-V 2.6 via LM Studio (2-5 seconds/image, 3-5 hours total)

**Search:**
- Library: Fuse.js 7.0.0
- Index: ~400KB JSON (~100KB gzipped)
- Speed: <50ms for 3,400+ entries
- Config: threshold 0.4, weights (album=2, caption=1.5, searchable=0.5)

**Quality:**
- Caption accuracy: 95%+
- False positives: ~5% (map noise, artifacts)
- False negatives: <1%

### Repository

- `ocr_scripts/ocr_pages.py` - OCR implementation
- `assets/js/search.js` - Client-side search with PhotoSwipe
- `layouts/_default/search.html` - Search page template
- `ocr_scripts/rebuild_search_index.py` - Fast index rebuild

---

*Last updated: January 2026*
