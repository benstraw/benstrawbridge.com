#!/usr/bin/env node
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const destination = await fs.mkdtemp(path.join(os.tmpdir(), 'ben-list-cards-'));

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

try {
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

  const cardsFor = (title) => blocks.filter(({ block }) => block.includes(`aria-label="${title}"`));
  const assertImageEverywhere = (title, alt) => {
    const matches = cardsFor(title);
    assert(matches.length > 0, `${title} was not found in any list`);
    for (const { file, block } of matches) {
      assert.match(block, /data-card-kind="image"/, `${title} did not use the image card in ${file}`);
      assert(block.includes(`alt="${alt}"`), `${title} did not render its curated alt text in ${file}`);
      assert(!block.includes('/images/og/generated/'), `${title} accidentally used generated OG artwork in ${file}`);
    }
  };

  assertImageEverywhere('Adding Leaflet to Ryder Theme', 'A Ryder theme page displaying an interactive Leaflet map');
  assertImageEverywhere('Tarragon Beets Salad', 'Finished tarragon beet salad with mushrooms, celery, grains, and seeds');

  const bundle = cardsFor('Adding Leaflet to Ryder Theme')[0].block;
  assert.match(bundle, /srcset="[^"]+ 480w,[^"]+ 760w,[^"]+ 1200w"/);
  assert.match(bundle, /object-contain object-top/);
  assert.match(bundle, /\/posts\/adding-leaflet-to-ryder-theme\//);

  const shared = cardsFor('Tarragon Beets Salad')[0].block;
  assert.match(shared, /\/images\/recipes\/tarragon-beets-salad\/beets-salad_hu_/);
  assert.match(shared, /object-cover object-center/);

  for (const { file, block } of cardsFor('Obsidian CLI')) {
    assert.doesNotMatch(block, /data-card-kind="image"/, `image-less authored page changed card type in ${file}`);
    assert.doesNotMatch(block, /<img\b/, `image-less authored page grew list media in ${file}`);
  }

  const trailTitle = 'Playa Vista Parks Walking Tour — A Self-Guided Dog-Friendly Loop';
  for (const { file, block } of cardsFor(trailTitle)) {
    assert.match(block, /data-card-kind="trail"/, `Trail lost specialized card precedence in ${file}`);
  }

  const fema = cardsFor('Federal Disaster Emergency Preparedness Kit Digitized')[0].block;
  assert.match(fema, /fema-logo-blue[^" ]*\.svg/);
  assert.doesNotMatch(fema, /srcset=/, 'SVG card media should render directly');
  assert.match(fema, /object-contain object-top/);

  const beatles = await fs.readFile(path.join(destination, 'musical-genres', 'classic-rock', 'index.html'), 'utf8');
  assert.match(beatles, /href="\/listening\/artists\/the-beatles\/"/);
  assert.doesNotMatch(beatles, /aria-label="The Beatles"[^]*data-card-kind="image"/, 'generated artist opted into authored image cards');

  console.log(`✓ list-card behavior verified across ${files.length} rendered list pages`);
} finally {
  await fs.rm(destination, { recursive: true, force: true });
}
