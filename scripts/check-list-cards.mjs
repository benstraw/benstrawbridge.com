#!/usr/bin/env node
// Verifies the per-page card-type mechanism documented in
// layouts/partials/utils/card-type.html and its layouts/_default/list.html
// fork: an authored page that declares `cardImage` gets the image card in
// every feed it appears in, a page that doesn't never grows list media, a
// specialized card (e.g. trail) keeps precedence over it, and a generated
// page (no .md source — taxonomy terms, listening/artist entries) can never
// opt in by accident.
//
// Content is discovered dynamically from front matter rather than pinned to
// hardcoded titles/alt-text/CSS classes, so editing or renaming a real post
// doesn't break this test — only a change to the underlying mechanism does.
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const destination = await fs.mkdtemp(path.join(os.tmpdir(), 'ben-list-cards-'));

// --- minimal front-matter reader --------------------------------------------
// Only reads the handful of single-line scalar fields this script needs.
// Not a TOML parser: array/table values and multi-line strings are ignored.
function readScalarField(frontMatter, key) {
  const match = frontMatter.match(new RegExp(`^${key}\\s*=\\s*(?:"([^"]*)"|'([^']*)'|(true|false))`, 'm'));
  if (!match) return undefined;
  if (match[3] !== undefined) return match[3] === 'true';
  return match[1] ?? match[2];
}

async function walkContentFiles(dir, result = []) {
  for (const entry of await fs.readdir(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) await walkContentFiles(full, result);
    else if (entry.name.endsWith('.md')) result.push(full);
  }
  return result;
}

async function loadContentIndex() {
  const files = (await walkContentFiles(path.join(root, 'content'))).sort();
  const pages = [];
  for (const file of files) {
    const raw = await fs.readFile(file, 'utf8');
    const match = raw.match(/^\+\+\+\n([\s\S]*?)\n\+\+\+/);
    if (!match) continue;
    const fm = match[1];
    pages.push({
      file: path.relative(root, file),
      isIndex: path.basename(file) === '_index.md',
      draft: readScalarField(fm, 'draft') === true,
      title: readScalarField(fm, 'title'),
      cardImage: readScalarField(fm, 'cardImage'),
      cardImageAlt: readScalarField(fm, 'cardImageAlt'),
      listCardType: readScalarField(fm, 'listCardType'),
    });
  }
  return pages;
}

// Section prefixes (relative to content/, e.g. "projects") whose own
// _index.md sets `listCardType = "-image"`. list.html reads that as the
// container's default card, so every item listed there renders with
// data-card-kind="image" whether or not it declares its own cardImage —
// card-image.html just falls back to card-category-color's markup when
// there is no real image. Check 4 below has to know about these sections,
// or it misreads "the container default" as "an unauthorized opt-in".
function imageDefaultSectionPrefixes(contentIndex) {
  return new Set(
    contentIndex
      .filter((p) => p.isIndex && p.listCardType === '-image')
      .map((p) => path.dirname(p.file).replace(/^content\/?/, '')),
  );
}

// --- rendered-HTML helpers ---------------------------------------------------
async function walk(dir, result = []) {
  for (const entry of await fs.readdir(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) await walk(full, result);
    else if (entry.name === 'index.html') result.push(full);
  }
  return result;
}

function articleBlocks(html) {
  const starts = [...html.matchAll(/<div itemscope="" itemtype="http:\/\/schema\.org\/Article"/g)].map((match) => match.index);
  return starts.map((start, index) => html.slice(start, starts[index + 1] ?? html.length));
}

// Go's html/template escapes attribute values, so a title or alt text with an
// apostrophe, quote, or ampersand never appears literally in the rendered
// HTML. Every comparison against front-matter text has to decode through
// this first, or it silently misses any page whose title isn't plain ASCII.
function decodeHtmlEntities(value) {
  return value
    .replace(/&#39;/g, "'")
    .replace(/&#x27;/gi, "'")
    .replace(/&quot;/g, '"')
    .replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>');
}

function blockHasAttr(block, attr, value) {
  const re = new RegExp(`${attr}="([^"]*)"`, 'g');
  for (const match of block.matchAll(re)) {
    if (decodeHtmlEntities(match[1]) === value) return true;
  }
  return false;
}

try {
  const contentIndex = await loadContentIndex();

  execFileSync('hugo', ['build', '--environment', 'development', '--destination', destination], {
    cwd: root,
    stdio: 'inherit',
  });

  const files = await walk(destination);
  const blocks = [];
  for (const file of files) {
    const html = await fs.readFile(file, 'utf8');
    for (const block of articleBlocks(html)) blocks.push({ file, block });
  }

  const cardsFor = (title) => blocks.filter(({ block }) => blockHasAttr(block, 'aria-label', title));

  // 1. Any authored page that opted into the image card via `cardImage`
  //    front matter renders as the image card everywhere it is listed, with
  //    a responsive srcset and an object-fit class, and never with generated
  //    OG artwork. Picks whichever such page sorts first, so this survives
  //    any single page being renamed or removed.
  const imageCardCandidates = contentIndex.filter((p) => !p.draft && !p.isIndex && p.cardImage && p.title);
  assert(imageCardCandidates.length > 0, 'no content page declares cardImage — the image-card opt-in mechanism has nothing to test against');
  const imageCardPage = imageCardCandidates[0];
  const imageMatches = cardsFor(imageCardPage.title);
  assert(imageMatches.length > 0, `${imageCardPage.title} (${imageCardPage.file}) was not found in any rendered list`);
  for (const { file, block } of imageMatches) {
    assert.match(block, /data-card-kind="image"/, `${imageCardPage.title} did not use the image card in ${file}`);
    const srcset = block.match(/srcset="([^"]*)"/);
    assert(srcset, `${imageCardPage.title} did not render a srcset in ${file}`);
    assert((srcset[1].match(/\d+w/g) ?? []).length >= 2, `${imageCardPage.title} rendered a srcset with fewer than 2 responsive widths in ${file}`);
    assert.match(block, /\bobject-\w+/, `${imageCardPage.title} did not carry an object-fit class in ${file}`);
    assert(!block.includes('/images/og/generated/'), `${imageCardPage.title} accidentally used generated OG artwork in ${file}`);
    if (imageCardPage.cardImageAlt) {
      assert(blockHasAttr(block, 'alt', imageCardPage.cardImageAlt), `${imageCardPage.title} did not render its own alt text in ${file}`);
    }
  }

  // 2. An authored page that did NOT opt in must never grow list media.
  //    Scoped to content/posts, which cascades no cardImage onto its
  //    children, so a match here is never a false positive from a parent
  //    section's [cascade].
  const noImageCandidates = contentIndex.filter((p) => !p.draft && !p.isIndex && !p.cardImage && p.title && p.file.startsWith('content/posts/'));
  assert(noImageCandidates.length > 0, 'no content/posts page without cardImage — the default-card path has nothing to test against');
  const noImagePage = noImageCandidates[0];
  for (const { file, block } of cardsFor(noImagePage.title)) {
    assert.doesNotMatch(block, /data-card-kind="image"/, `${noImagePage.title} (no cardImage) unexpectedly used the image card in ${file}`);
    assert.doesNotMatch(block, /<img\b/, `${noImagePage.title} (no cardImage) unexpectedly grew list media in ${file}`);
  }

  // 3. A trail always keeps its specialized card, wherever it is listed —
  //    picking whichever real trail sorts first rather than one hardcoded
  //    title.
  const trailPages = contentIndex.filter((p) => !p.draft && !p.isIndex && p.file.startsWith('content/trails/') && p.title);
  assert(trailPages.length > 0, 'no trail content found to test specialized card precedence');
  const trailPage = trailPages[0];
  const trailMatches = cardsFor(trailPage.title);
  assert(trailMatches.length > 0, `${trailPage.title} (${trailPage.file}) was not found in any rendered list`);
  for (const { file, block } of trailMatches) {
    assert.match(block, /data-card-kind="trail"/, `${trailPage.title} lost specialized card precedence in ${file}`);
  }

  // 4. Generated pages (taxonomy terms, listening/artist entries, etc.) have
  //    no .md source and so must never render with the image card via the
  //    per-page opt-in, no matter which one might trigger it — checked by
  //    cross-referencing every image card in a non-"-image"-default section
  //    against the full set of real pages that actually declared cardImage,
  //    rather than spot-checking one hardcoded generated page. Sections
  //    whose own container defaults to "-image" (see imageDefaultSectionPrefixes)
  //    are exempt: there, every item gets the image card regardless of
  //    opt-in, by design.
  const authoredImageTitles = new Set(contentIndex.filter((p) => p.cardImage && p.title).map((p) => p.title));
  const imageDefaultSections = imageDefaultSectionPrefixes(contentIndex);
  let imageCardCount = 0;
  for (const { file, block } of blocks) {
    if (!/data-card-kind="image"/.test(block)) continue;
    imageCardCount += 1;
    const section = path.relative(destination, file).split(path.sep)[0];
    if (imageDefaultSections.has(section)) continue;
    const ariaLabel = block.match(/aria-label="([^"]*)"/);
    assert(ariaLabel, `an image card in ${file} has no aria-label to identify its page`);
    const decodedLabel = decodeHtmlEntities(ariaLabel[1]);
    assert(
      authoredImageTitles.has(decodedLabel),
      `"${decodedLabel}" rendered with the image card in ${file} but no content page with that title declares cardImage — a generated or unrelated page may have opted in by accident`,
    );
  }
  assert(imageCardCount > 0, 'no image cards were rendered anywhere in the site — the card-type mechanism may be broken');

  // 5. SVG-sourced card media renders directly, without a responsive
  //    srcset — checked structurally across every card in the build, not
  //    against one hardcoded page.
  for (const { file, block } of blocks) {
    if (!/<img[^>]+src="[^"]*\.svg"/.test(block)) continue;
    assert.doesNotMatch(block, /srcset=/, `an SVG-sourced card in ${file} unexpectedly rendered a srcset`);
  }

  console.log(
    `✓ list-card behavior verified across ${files.length} rendered list pages ` +
      `(${imageCardCount} image cards; used "${imageCardPage.title}", "${noImagePage.title}", and "${trailPage.title}" as this run's fixtures)`,
  );
} finally {
  await fs.rm(destination, { recursive: true, force: true });
}
