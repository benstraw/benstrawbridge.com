#!/usr/bin/env node

import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const PUBLIC = path.join(ROOT, 'public');
const CONTENT = path.join(ROOT, 'content');
const MANIFEST = path.join(ROOT, 'assets', 'images', 'og', 'generated', 'manifest.json');
const OUTPUT = path.join(ROOT, 'static', 'og-tests');
const CHECK = process.argv.includes('--check');
const SITE = 'https://www.benstrawbridge.com';

const PALETTE_GROUPS = new Set(['posts', 'projects', 'trails', 'recipes', 'links', 'listening']);
const GROUP_LABELS = {
  posts: 'Posts',
  projects: 'Projects',
  trails: 'Trails',
  recipes: 'Recipes',
  links: 'Links',
  listening: 'Listening & genres',
  misc: 'Fine print & miscellaneous',
};
const MAIN_GROUPS = ['posts', 'projects', 'trails', 'recipes', 'links', 'misc'];
const ALL_GROUPS = [...MAIN_GROUPS.slice(0, -1), 'listening', 'misc'];

function escapeHtml(value) {
  return String(value)
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;');
}

function decodeHtml(value) {
  return value
    .replace(/&#(\d+);/g, (_, code) => String.fromCodePoint(Number(code)))
    .replace(/&#x([\da-f]+);/gi, (_, code) => String.fromCodePoint(Number.parseInt(code, 16)))
    .replaceAll('&quot;', '"')
    .replaceAll('&#39;', "'")
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&amp;', '&');
}

function groupFor(section) {
  return PALETTE_GROUPS.has(section) ? section : 'misc';
}

function relativePublicPath(canonical, filename = 'index.html') {
  const relative = decodeURIComponent(canonical).replace(/^\/+|\/+$/g, '');
  return path.join(PUBLIC, relative, filename);
}

async function titleFor(canonical) {
  try {
    const html = await fs.readFile(relativePublicPath(canonical, 'og-card.html'), 'utf8');
    const title = html.match(/<title>([\s\S]*?)<\/title>/i)?.[1] || '';
    return decodeHtml(title).replace(/\s+—\s+OG card source\s*$/, '').trim();
  } catch {
    const part = canonical.split('/').filter(Boolean).at(-1) || 'Home';
    return decodeURIComponent(part).replaceAll('-', ' ').replace(/\b\w/g, (letter) => letter.toUpperCase());
  }
}

async function walkMarkdown(directory, found = []) {
  for (const entry of await fs.readdir(directory, { withFileTypes: true })) {
    const absolute = path.join(directory, entry.name);
    if (entry.isDirectory()) await walkMarkdown(absolute, found);
    else if (entry.name.endsWith('.md')) found.push(absolute);
  }
  return found;
}

function canonicalForMarkdown(file) {
  const relative = path.relative(CONTENT, file).split(path.sep).join('/');
  const parsed = path.posix.parse(relative);
  const stem = ['index', '_index'].includes(parsed.name) ? parsed.dir : path.posix.join(parsed.dir, parsed.name);
  return stem ? `/${stem}/`.replace(/\/{2,}/g, '/') : '/';
}

function metaImage(html) {
  const tag = html.match(/<meta\s+[^>]*property=(?:["']?og:image["']?)[^>]*>/i)?.[0] || '';
  const match = tag.match(/content=(?:"([^"]+)"|'([^']+)'|([^\s>]+))/i);
  if (!match) return null;
  const value = decodeHtml(match[1] || match[2] || match[3]);
  try {
    return new URL(value, 'https://www.benstrawbridge.com').pathname;
  } catch {
    return value;
  }
}

async function manualCards() {
  const cards = [];
  for (const file of await walkMarkdown(CONTENT)) {
    const source = await fs.readFile(file, 'utf8');
    if (!/^og_image\s*=\s*["'][^"']+["']/m.test(source)) continue;
    const canonical = canonicalForMarkdown(file);
    const titleMatch = source.match(/^title\s*=\s*(["'])(.*?)\1\s*$/m);
    const pageHtml = await fs.readFile(relativePublicPath(canonical), 'utf8');
    const image = metaImage(pageHtml);
    if (!image) throw new Error(`${canonical}: manual og_image did not render into page metadata`);
    cards.push({
      canonical,
      group: groupFor(canonical.split('/').filter(Boolean)[0] || 'misc'),
      image,
      layout: 'manual',
      section: canonical.split('/').filter(Boolean)[0] || 'other',
      title: titleMatch ? titleMatch[2] : await titleFor(canonical),
    });
  }
  cards.push({ canonical: '/tanda-light/', group: 'misc', image: '/tanda-light/tanda-og.png', layout: 'manual', section: 'tanda-light', title: 'Tanda Light' });
  return cards;
}

function sortItems(items) {
  return [...items].sort((a, b) => {
    if (a.canonical === '/') return -1;
    if (b.canonical === '/') return 1;
    return a.canonical.localeCompare(b.canonical);
  });
}

function searchText(item) {
  return `${item.title} ${item.canonical} ${item.section} ${item.group} ${item.layout}`.toLowerCase();
}

function pageHref(canonical) {
  return new URL(canonical, SITE).href;
}

function imageCard(item, { generic = false } = {}) {
  const variant = (Buffer.byteLength(item.canonical) % 4) + 1;
  const badge = generic ? `field ${variant}` : item.layout;
  return `<article class="review-card" data-review-entry data-search="${escapeHtml(searchText(item))}">
  <a class="image-link" href="${escapeHtml(item.image)}"><img src="${escapeHtml(item.image)}" width="1200" height="630" alt="${escapeHtml(item.title)} Open Graph card" loading="lazy" decoding="async"></a>
  <div class="caption"><div><strong><a href="${escapeHtml(pageHref(item.canonical))}">${escapeHtml(item.title)}</a></strong><small>${escapeHtml(item.canonical)}</small></div><span class="badge">${escapeHtml(badge)}</span></div>
</article>`;
}

function genericBlock(items, group) {
  if (!items.length) return '';
  const example = items[0];
  const links = items.map((item) => `<li data-review-entry data-search="${escapeHtml(searchText(item))}"><a href="${escapeHtml(pageHref(item.canonical))}">${escapeHtml(item.title)}</a><small>${escapeHtml(item.canonical)}</small></li>`).join('\n');
  return `<div class="generic-block">
  <h3>Generic no-image template</h3>
  <article class="review-card generic-example">
    <a class="image-link" href="${escapeHtml(example.image)}"><img src="${escapeHtml(example.image)}" width="1200" height="630" alt="${escapeHtml(GROUP_LABELS[group])} generic Open Graph card" loading="lazy" decoding="async"></a>
    <div class="caption"><div><strong>${escapeHtml(example.title)}</strong><small>${escapeHtml(example.canonical)}</small></div><span class="badge">abstract</span></div>
  </article>
  <details class="page-list"><summary>Every page using this template · ${items.length}</summary><ul class="generic-list">${links}</ul></details>
</div>`;
}

function nav(active) {
  const links = [
    ['main', '/og-tests/', 'Image cards'],
    ['listening', '/og-tests/listening/', 'Listening'],
    ['generic', '/og-tests/generic/', 'No-image templates'],
  ];
  return `<nav class="nav-links" aria-label="OG test pages">${links.map(([key, href, label]) => `<a href="${href}"${key === active ? ' aria-current="page"' : ''}>${label}</a>`).join('')}</nav>`;
}

function documentShell({ active, title, lede, entryCount, groups, body }) {
  const jumps = groups.map((group) => `<a href="#section-${group}">${escapeHtml(GROUP_LABELS[group])}</a>`).join('');
  return `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="robots" content="noindex,nofollow">
  <meta http-equiv="Content-Security-Policy" content="default-src 'self'; script-src 'self'; style-src 'self'; img-src 'self' data:; frame-ancestors 'none'; form-action 'self'; base-uri 'self'; object-src 'none'">
  <title>${escapeHtml(title)} · Ben Strawbridge</title>
  <link rel="stylesheet" href="/og-tests/styles.css">
</head>
<body>
  <!-- Generated by scripts/generate-og-tests.mjs; edit the generator or shared static assets. -->
  <header class="masthead"><div class="shell">
    <p class="wordmark"><span>Ben</span> <span>Strawbridge</span></p>
    <h1>${escapeHtml(title)}</h1>
    <p class="lede">${escapeHtml(lede)}</p>
    ${nav(active)}
  </div></header>
  <div class="tools"><div class="shell">
    <div class="tool-row"><label><input id="search" type="search" placeholder="Filter by title, path, section, or layout…" autocomplete="off"></label><span class="count"><strong id="visible-count">${entryCount.toLocaleString('en-US')}</strong> / ${entryCount.toLocaleString('en-US')} pages</span></div>
    <nav class="jump-links" aria-label="Jump to section">${jumps}</nav>
  </div></div>
  <main class="shell">${body}</main>
  <script defer src="/og-tests/gallery.js"></script>
</body>
</html>
`;
}

function reviewSection(group, imageItems, genericItems) {
  const images = imageItems.filter((item) => item.group === group);
  const generics = genericItems.filter((item) => item.group === group);
  const gallery = images.length ? `<h3>Image-driven and custom cards</h3><div class="gallery">${images.map((item) => imageCard(item)).join('\n')}</div>` : '';
  return `<section class="image-section" id="section-${group}" data-gallery-section>
  <div class="section-heading"><h2>${escapeHtml(GROUP_LABELS[group])}</h2><span class="section-total">${images.length} image cards · ${generics.length} generic pages</span></div>
  ${gallery}
  ${genericBlock(generics, group)}
  <p class="empty">No pages in this section match the current filter.</p>
</section>`;
}

function reviewPage({ listeningOnly, images, generics }) {
  const groups = listeningOnly ? ['listening'] : MAIN_GROUPS;
  const selectedImages = images.filter((item) => listeningOnly === (item.group === 'listening'));
  const selectedGenerics = generics.filter((item) => listeningOnly === (item.group === 'listening'));
  const body = groups.map((group) => reviewSection(group, selectedImages, selectedGenerics)).join('\n');
  return documentShell({
    active: listeningOnly ? 'listening' : 'main',
    title: listeningOnly ? 'Listening OG images' : 'OG image review',
    lede: listeningOnly
      ? 'Image-driven artist cards first, followed by the listening palette and a collapsed list of every page using its generic template.'
      : 'Each section starts with image-driven and custom cards, then shows its generic example and a collapsed list of every page using that template.',
    entryCount: selectedImages.length + selectedGenerics.length,
    groups,
    body,
  });
}

function genericPage(generics) {
  const body = ALL_GROUPS.map((group) => {
    const items = generics.filter((item) => item.group === group);
    return `<section class="image-section" id="section-${group}" data-gallery-section>
  <div class="section-heading"><h2>${escapeHtml(GROUP_LABELS[group])}</h2><span class="section-total">${items.length} generated no-image cards</span></div>
  <div class="gallery">${items.map((item) => imageCard(item, { generic: true })).join('\n')}</div>
  <p class="empty">No templates in this section match the current filter.</p>
</section>`;
  }).join('\n');
  return documentShell({
    active: 'generic',
    title: 'Generated no-image templates',
    lede: 'Every current abstract card whose page has no selected source image, grouped by palette. The field badge identifies the four deterministic blob arrangements.',
    entryCount: generics.length,
    groups: ALL_GROUPS,
    body,
  });
}

async function writeOrCheck(relative, contents) {
  const destination = path.join(OUTPUT, relative);
  if (CHECK) {
    const existing = await fs.readFile(destination, 'utf8').catch(() => '');
    if (existing !== contents) throw new Error(`${path.relative(ROOT, destination)} is missing or stale; run npm run og:gallery`);
    return;
  }
  await fs.mkdir(path.dirname(destination), { recursive: true });
  await fs.writeFile(destination, contents);
}

async function main() {
  const manifest = JSON.parse(await fs.readFile(MANIFEST, 'utf8'));
  const generated = [];
  for (const [canonical, card] of Object.entries(manifest.cards)) {
    generated.push({
      canonical,
      group: groupFor(card.section),
      image: `/images/og/generated/${card.output}`,
      layout: card.layout,
      section: card.section,
      title: await titleFor(canonical),
    });
  }
  const generics = sortItems(generated.filter((item) => item.layout === 'abstract'));
  const images = sortItems([
    ...generated.filter((item) => item.layout !== 'abstract'),
    ...await manualCards(),
  ]);

  await writeOrCheck('index.html', reviewPage({ listeningOnly: false, images, generics }));
  await writeOrCheck(path.join('listening', 'index.html'), reviewPage({ listeningOnly: true, images, generics }));
  await writeOrCheck(path.join('generic', 'index.html'), genericPage(generics));
  console.log(`${CHECK ? '✓ checked' : '✓ wrote'} OG test pages (${images.length} image cards, ${generics.length} no-image templates)`);
}

main().catch((error) => {
  console.error(`✗ ${error.message}`);
  process.exitCode = 1;
});
