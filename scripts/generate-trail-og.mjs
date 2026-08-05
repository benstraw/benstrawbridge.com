#!/usr/bin/env node
/*
 * Generate the Open Graph card image for each trail page.
 *
 * Hugo renders the card source to /trails/<slug>/og-card.html (the OGCard
 * output format, template at layouts/trails/single.ogcard.html). This script
 * builds the site, serves public/ locally, photographs each card at 1200x630,
 * writes og-cover.jpg into the trail's page bundle, and points that page's
 * front matter at it. Front matter is only touched once every card has
 * succeeded, so a page can never end up naming an image that is not on disk.
 *
 * The card is a live Leaflet map, so this needs the tile hosts to be reachable:
 *   basemap.nationalmap.gov   (USGS topo, Hiking Tours)
 *   *.basemaps.cartocdn.com   (CARTO voyager, Walking Tours)
 * Claude Code on the web blocks both, so run this locally.
 *
 * Usage:
 *   npm run og:trails                     # all trails
 *   npm run og:trails -- --only pv-tour   # one trail
 *   npm run og:trails -- --skip-build     # reuse the existing public/
 *   npm run og:trails -- --stub-tiles     # fake the tiles (pipeline check only)
 */

import { createServer } from 'node:http';
import { execFileSync } from 'node:child_process';
import { createReadStream } from 'node:fs';
import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const REPO_ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const PUBLIC_DIR = path.join(REPO_ROOT, 'public');
const TRAILS_CONTENT = path.join(REPO_ROOT, 'content', 'trails');
const CARD_NAME = 'og-cover.jpg';
/* Cards used to be PNG. A screenshot of photographic topo tiles compresses
   terribly as PNG — the originals ran 0.85-1.4MB each against ~150KB as JPEG,
   for no visible difference. Any leftover PNG is deleted as its JPEG lands. */
const LEGACY_CARD_NAME = 'og-cover.png';
const JPEG_QUALITY = 88;
const WIDTH = 1200;
const HEIGHT = 630;
const READY_TIMEOUT_MS = 45_000;

/* 1x1 PNG, used only by --stub-tiles to exercise this script where the real
   tile CDNs are unreachable. Leaflet stretches it over every tile, so the
   resulting card is a flat colour where the map should be — useful for
   checking the plumbing, never for a card you would actually ship. */
const STUB_TILE = Buffer.from(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGN4dv8SAAVGApjzYKUrAAAAAElFTkSuQmCC',
  'base64'
);

const MIME = {
  '.html': 'text/html; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.webp': 'image/webp',
  '.svg': 'image/svg+xml',
  '.gpx': 'application/gpx+xml',
  '.ttf': 'font/ttf',
  '.woff2': 'font/woff2',
};

function parseArgs(argv) {
  const opts = { only: null, skipBuild: false, stubTiles: false };
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (arg === '--only') opts.only = argv[++i];
    else if (arg === '--skip-build') opts.skipBuild = true;
    else if (arg === '--stub-tiles') opts.stubTiles = true;
    else throw new Error(`unknown argument: ${arg}`);
  }
  if (opts.only === undefined || opts.only === '') {
    throw new Error('--only needs a trail slug');
  }
  return opts;
}

async function loadPlaywright() {
  try {
    return await import('playwright');
  } catch {
    throw new Error(
      'playwright is not installed. Run `npm install`, then ' +
        '`npx playwright install chromium`.'
    );
  }
}

function build() {
  // --environment development on purpose: the production config enables
  // autoprefixer, whose browserslist lookup walks above the repo root. See
  // CLAUDE.md. Real production builds happen on Amplify.
  console.log('› hugo build --environment development');
  execFileSync('hugo', ['build', '--environment', 'development'], {
    cwd: REPO_ROOT,
    stdio: 'inherit',
  });
}

/* Minimal static file server for public/. Deliberately dependency-free — the
   only thing it has to serve is a handful of local files to a local browser. */
function serve() {
  const server = createServer(async (req, res) => {
    try {
      const url = new URL(req.url, 'http://localhost');
      let rel = decodeURIComponent(url.pathname);
      if (rel.endsWith('/')) rel += 'index.html';

      const filePath = path.join(PUBLIC_DIR, path.normalize(rel));
      if (!filePath.startsWith(PUBLIC_DIR)) {
        res.writeHead(403).end('forbidden');
        return;
      }

      const stat = await fs.stat(filePath);
      if (!stat.isFile()) {
        res.writeHead(404).end('not found');
        return;
      }

      res.writeHead(200, {
        'Content-Type': MIME[path.extname(filePath).toLowerCase()] ?? 'application/octet-stream',
        'Content-Length': stat.size,
        'Cache-Control': 'no-store',
      });
      createReadStream(filePath).pipe(res);
    } catch {
      res.writeHead(404).end('not found');
    }
  });

  return new Promise((resolve) => {
    server.listen(0, '127.0.0.1', () => resolve({ server, port: server.address().port }));
  });
}

async function findCards(only) {
  const trailsOut = path.join(PUBLIC_DIR, 'trails');
  let entries;
  try {
    entries = await fs.readdir(trailsOut, { withFileTypes: true });
  } catch {
    throw new Error(`no built trails at ${trailsOut} — build first, or drop --skip-build`);
  }

  const slugs = [];
  for (const entry of entries) {
    if (!entry.isDirectory()) continue;
    if (only && entry.name !== only) continue;
    try {
      await fs.access(path.join(trailsOut, entry.name, 'og-card.html'));
      slugs.push(entry.name);
    } catch {
      // No card for this directory. Only worth complaining about when the user
      // asked for it by name.
      if (only) {
        throw new Error(
          `${only} has no og-card.html — check that content/trails/_index.md ` +
            'still cascades outputs = ["HTML", "OGCard"]'
        );
      }
    }
  }

  if (slugs.length === 0) {
    throw new Error(only ? `no trail named ${only}` : 'no trail cards found');
  }
  return slugs.sort();
}

async function shoot(page, port, slug, stubTiles) {
  const url = `http://127.0.0.1:${port}/trails/${encodeURIComponent(slug)}/og-card.html`;

  const consoleErrors = [];
  const onConsole = (msg) => {
    if (msg.type() === 'error') consoleErrors.push(msg.text());
  };
  page.on('console', onConsole);

  try {
    await page.goto(url, { waitUntil: 'domcontentloaded' });

    try {
      await page.waitForFunction(() => window.__ogCardReady === true, null, {
        timeout: READY_TIMEOUT_MS,
      });
    } catch {
      throw new Error(
        `card never signalled ready within ${READY_TIMEOUT_MS / 1000}s` +
          (consoleErrors.length ? `\n    console: ${consoleErrors[0]}` : '')
      );
    }

    const cardError = await page.evaluate(() => window.__ogCardError);
    if (cardError) throw new Error(cardError);

    const tileErrors = await page.evaluate(() => window.__ogCardTileErrors);
    if (tileErrors > 0 && !stubTiles) {
      throw new Error(
        `${tileErrors} map tile(s) failed to load — the card would have holes ` +
          'in it. Check network access to the tile host and retry.'
      );
    }

    const out = path.join(TRAILS_CONTENT, slug, CARD_NAME);
    await page.screenshot({ path: out, type: 'jpeg', quality: JPEG_QUALITY });
    return path.relative(REPO_ROOT, out);
  } finally {
    page.off('console', onConsole);
  }
}

/* Point a trail's front matter at the card and drop any stale PNG.
 *
 * The partial that consumes og_image (the theme's get-featured-image.html)
 * calls errorf when it cannot resolve the path, so front matter that names a
 * missing file breaks the build for everyone. Having this script own both
 * sides means they cannot drift: the line is only written once the image it
 * names is on disk, and the whole pass only runs after every card succeeded.
 */
async function finalize(slug) {
  const changes = [];
  const bundle = path.join(TRAILS_CONTENT, slug);

  const legacy = path.join(bundle, LEGACY_CARD_NAME);
  try {
    await fs.unlink(legacy);
    changes.push(`removed ${LEGACY_CARD_NAME}`);
  } catch {
    // Nothing to clean up.
  }

  const indexPath = path.join(bundle, 'index.md');
  const source = await fs.readFile(indexPath, 'utf8');
  const wanted = `og_image = "${CARD_NAME}"`;

  if (source.includes(`\n${wanted}\n`)) return changes;

  let updated;
  if (/^og_image\s*=.*$/m.test(source)) {
    updated = source.replace(/^og_image\s*=.*$/m, wanted);
  } else if (/^gpx\s*=.*$/m.test(source)) {
    // Sits with the other resource-naming keys rather than at the top.
    updated = source.replace(/^(gpx\s*=.*)$/m, `$1\n${wanted}`);
  } else {
    updated = source.replace(/^\+\+\+\n/, `+++\n${wanted}\n`);
  }

  if (updated === source) {
    throw new Error(`could not place og_image in ${path.relative(REPO_ROOT, indexPath)}`);
  }

  await fs.writeFile(indexPath, updated);
  changes.push('set og_image');
  return changes;
}

async function main() {
  const opts = parseArgs(process.argv.slice(2));
  const { chromium } = await loadPlaywright();

  if (!opts.skipBuild) build();

  const slugs = await findCards(opts.only);
  const { server, port } = await serve();
  console.log(`› serving public/ on 127.0.0.1:${port}`);

  const browser = await chromium.launch();
  const context = await browser.newContext({
    viewport: { width: WIDTH, height: HEIGHT },
    deviceScaleFactor: 1,
  });

  // Verification hook: answer every tile request locally so the rest of the
  // pipeline can be exercised where the tile CDNs are unreachable.
  if (opts.stubTiles) {
    console.warn(
      '› --stub-tiles: cards will have NO real map, and committed ones will be\n' +
        '  overwritten. Pipeline check only — `git checkout content/trails/` after.'
    );
    await context.route(
      (url) =>
        url.hostname === 'basemap.nationalmap.gov' ||
        url.hostname.endsWith('.basemaps.cartocdn.com'),
      (route) => route.fulfill({ status: 200, contentType: 'image/png', body: STUB_TILE })
    );
  }

  const page = await context.newPage();

  const failures = [];
  const shot = [];
  try {
    for (const slug of slugs) {
      process.stdout.write(`  ${slug} … `);
      try {
        const out = await shoot(page, port, slug, opts.stubTiles);
        console.log(`✓ ${out}`);
        shot.push(slug);
      } catch (err) {
        console.log('✗');
        failures.push(`${slug}: ${err.message}`);
      }
    }
  } finally {
    await browser.close();
    server.close();
  }

  if (failures.length > 0) {
    console.error(`\n${failures.length} card(s) failed:`);
    for (const failure of failures) console.error(`  - ${failure}`);
    console.error('\nNo front matter was touched — fix the above and re-run.');
    process.exitCode = 1;
    return;
  }

  // Only once every card is on disk, so a partial run can never leave a page
  // pointing at an image that is not there.
  console.log('› updating front matter');
  for (const slug of shot) {
    const changes = await finalize(slug);
    if (changes.length > 0) console.log(`  ${slug} … ${changes.join(', ')}`);
  }

  console.log('\nDone. Review the cards, then commit the images and index.md together.');
}

main().catch((err) => {
  console.error(`\n${err.message}`);
  process.exitCode = 1;
});
