#!/usr/bin/env node

import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const PUBLIC = path.join(ROOT, 'public');

const copies = [
  ['static/og-tests', 'og-tests'],
  ['assets/images/og/generated', 'images/og/generated'],
  ['content/posts/screenshot-a-day/og.png', 'posts/screenshot-a-day/og.png'],
  [
    'content/posts/the-towers-i-loved-and-the-day-they-fell/wtc_sunset_2000_soft.jpg',
    'posts/the-towers-i-loved-and-the-day-they-fell/wtc_sunset_2000_soft.jpg',
  ],
  ['static/tanda-light/tanda-og.png', 'tanda-light/tanda-og.png'],
];

async function copy(source, destination) {
  const from = path.join(ROOT, source);
  const to = path.join(PUBLIC, destination);
  await fs.mkdir(path.dirname(to), { recursive: true });
  await fs.cp(from, to, { recursive: true });
}

async function main() {
  await fs.rm(PUBLIC, { recursive: true, force: true });
  await fs.mkdir(PUBLIC, { recursive: true });
  for (const [source, destination] of copies) await copy(source, destination);
  await fs.writeFile(
    path.join(PUBLIC, 'index.html'),
    '<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="robots" content="noindex,nofollow"><meta http-equiv="refresh" content="0;url=/og-tests/"><title>OG image review</title></head><body><p><a href="/og-tests/">Open the OG image review</a></p></body></html>\n',
  );
  console.log('✓ staged the PR 122 OG review artifact');
}

main().catch((error) => {
  console.error(`✗ ${error.message}`);
  process.exitCode = 1;
});
