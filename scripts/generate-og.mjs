#!/usr/bin/env node
import { createServer } from 'node:http';
import { execFileSync } from 'node:child_process';
import { createReadStream, existsSync } from 'node:fs';
import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import {
  HEIGHT,
  JPEG_QUALITY,
  RENDERER_VERSION,
  WIDTH,
  fingerprintHtml,
  jpegDimensions,
  matchesFilters,
  normalizeCanonical,
  outputRelative,
  parseOgArgs,
} from './og-lib.mjs';

const REPO_ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const PUBLIC_DIR = path.join(REPO_ROOT, 'public');
const GENERATED_DIR = path.join(REPO_ROOT, 'assets', 'images', 'og', 'generated');
const MANIFEST_PATH = path.join(GENERATED_DIR, 'manifest.json');
const PREINSTALLED_CHROMIUM = '/opt/pw-browsers/chromium';
const READY_TIMEOUT_MS = 45_000;
const MIME = {
  '.html': 'text/html; charset=utf-8', '.css': 'text/css; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8', '.json': 'application/json',
  '.png': 'image/png', '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg',
  '.webp': 'image/webp', '.svg': 'image/svg+xml', '.gpx': 'application/gpx+xml',
  '.ttf': 'font/ttf', '.woff2': 'font/woff2',
};

function build() {
  console.log('› hugo build --cleanDestinationDir --environment development');
  execFileSync('hugo', ['build', '--cleanDestinationDir', '--environment', 'development'], { cwd: REPO_ROOT, stdio: 'inherit' });
}

async function walk(dir, name, found = []) {
  for (const entry of await fs.readdir(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) await walk(full, name, found);
    else if (entry.name === name) found.push(full);
  }
  return found;
}

async function generatedJpegs(dir = GENERATED_DIR, found = []) {
  try {
    for (const entry of await fs.readdir(dir, { withFileTypes: true })) {
      const full = path.join(dir, entry.name);
      if (entry.isDirectory()) await generatedJpegs(full, found);
      else if (/\.jpe?g$/i.test(entry.name)) found.push(path.relative(GENERATED_DIR, full).split(path.sep).join('/'));
    }
  } catch (error) {
    if (error.code !== 'ENOENT') throw error;
  }
  return found;
}

async function orphanedAssets(cards) {
  const desired = new Set(cards.map((card) => card.outputRel));
  return (await generatedJpegs()).filter((file) => !desired.has(file));
}

async function discoverCards(opts) {
  const files = await walk(PUBLIC_DIR, 'og-card.html');
  const cards = [];
  for (const sourceFile of files) {
    const html = await fs.readFile(sourceFile, 'utf8');
    const marker = html.match(/<div id="og-card"([^>]*)>/);
    if (!marker) continue;
    const attr = Object.fromEntries([...marker[1].matchAll(/\sdata-og-([\w-]+)="([^"]*)"/g)].map((m) => [m[1], m[2].replaceAll('&amp;', '&')]));
    if (attr.eligible !== 'true') continue;
    const canonical = normalizeCanonical(attr.canonical);
    const card = {
      canonical,
      section: attr.section || (canonical.split('/')[1] || 'home'),
      layout: attr.layout || (attr.section === 'trails' ? 'trail' : ''),
      sourceFile,
      sourceUrl: `/${path.relative(PUBLIC_DIR, sourceFile).split(path.sep).join('/')}`,
      html,
      fingerprint: fingerprintHtml(html),
      metadataEnabled: attr['metadata-enabled'] === 'true',
      outputRel: outputRelative(canonical),
    };
    if (!matchesFilters(card, opts)) continue;
    cards.push(card);
  }
  cards.sort((a, b) => a.canonical.localeCompare(b.canonical));
  if (opts.onlyPaths?.length) {
    const found = new Set(cards.map((card) => card.canonical));
    const missing = opts.onlyPaths.filter((canonical) => !found.has(canonical));
    if (missing.length) throw new Error(`no eligible card for ${missing.join(', ')}`);
  } else if (opts.only && cards.length === 0) throw new Error(`no eligible card for ${opts.only}`);
  if (opts.section && cards.length === 0) throw new Error(`no eligible cards in section ${opts.section}`);
  return cards;
}

async function readManifest() {
  try {
    const manifest = JSON.parse(await fs.readFile(MANIFEST_PATH, 'utf8'));
    return manifest.cards ? manifest : { version: RENDERER_VERSION, cards: {} };
  } catch (error) {
    if (error.code === 'ENOENT') return { version: RENDERER_VERSION, cards: {} };
    throw error;
  }
}

async function validateOutput(card) {
  const output = path.join(GENERATED_DIR, card.outputRel);
  try {
    const dimensions = jpegDimensions(await fs.readFile(output));
    if (dimensions.width !== WIDTH || dimensions.height !== HEIGHT) return `wrong dimensions ${dimensions.width}x${dimensions.height}`;
  } catch (error) {
    return error.code === 'ENOENT' ? 'missing image' : error.message;
  }
  return null;
}

async function statusFor(cards, manifest) {
  const problems = [];
  for (const card of cards) {
    const entry = manifest.cards[card.canonical];
    if (!entry) problems.push({ card, reason: 'missing manifest entry' });
    else if (entry.fingerprint !== card.fingerprint) problems.push({ card, reason: 'stale render fingerprint' });
    else {
      const invalid = await validateOutput(card);
      if (invalid) problems.push({ card, reason: invalid });
    }
  }
  return problems;
}

function serve() {
  const server = createServer(async (req, res) => {
    try {
      const url = new URL(req.url, 'http://localhost');
      let rel = decodeURIComponent(url.pathname);
      if (rel.endsWith('/')) rel += 'index.html';
      const filePath = path.resolve(PUBLIC_DIR, `.${rel}`);
      if (!filePath.startsWith(`${PUBLIC_DIR}${path.sep}`)) return res.writeHead(403).end('forbidden');
      const stat = await fs.stat(filePath);
      if (!stat.isFile()) return res.writeHead(404).end('not found');
      res.writeHead(200, { 'Content-Type': MIME[path.extname(filePath).toLowerCase()] || 'application/octet-stream', 'Content-Length': stat.size, 'Cache-Control': 'no-store' });
      createReadStream(filePath).pipe(res);
    } catch { res.writeHead(404).end('not found'); }
  });
  return new Promise((resolve) => server.listen(0, '127.0.0.1', () => resolve({ server, port: server.address().port })));
}

async function loadPlaywright() {
  try { return await import('playwright'); }
  catch { throw new Error('playwright is not installed. Run npm install and npx playwright install chromium.'); }
}

async function launchChromium(chromium) {
  const proxyServer = process.env.HTTPS_PROXY || process.env.https_proxy;
  const opts = proxyServer ? { proxy: { server: proxyServer, bypass: '127.0.0.1,localhost,::1' } } : {};
  try { return await chromium.launch(opts); }
  catch (error) {
    if (!existsSync(PREINSTALLED_CHROMIUM)) throw error;
    console.warn(`› playwright browser missing; using ${PREINSTALLED_CHROMIUM}`);
    return chromium.launch({ ...opts, executablePath: PREINSTALLED_CHROMIUM });
  }
}

async function shoot(page, port, card, stubTiles) {
  const consoleErrors = [];
  const onConsole = (msg) => { if (msg.type() === 'error') consoleErrors.push(msg.text()); };
  page.on('console', onConsole);
  try {
    await page.goto(`http://127.0.0.1:${port}${card.sourceUrl}`, { waitUntil: 'domcontentloaded', timeout: READY_TIMEOUT_MS });
    await page.waitForFunction(() => window.__ogCardReady === true, null, { timeout: READY_TIMEOUT_MS });
    const error = await page.evaluate(() => window.__ogCardError);
    if (error) throw new Error(error);
    if (card.section === 'trails' && !stubTiles) {
      const tileErrors = await page.evaluate(() => window.__ogCardTileErrors || 0);
      if (tileErrors > 0) throw new Error(`${tileErrors} map tile(s) failed`);
    }
    const output = path.join(GENERATED_DIR, card.outputRel);
    await fs.mkdir(path.dirname(output), { recursive: true });
    await page.screenshot({ path: output, type: 'jpeg', quality: JPEG_QUALITY });
  } catch (error) {
    if (consoleErrors.length) error.message += `; console: ${consoleErrors[0]}`;
    throw error;
  } finally { page.off('console', onConsole); }
}

async function writeManifest(manifest) {
  manifest.version = RENDERER_VERSION;
  manifest.cards = Object.fromEntries(Object.entries(manifest.cards).sort(([a], [b]) => a.localeCompare(b)));
  await fs.mkdir(GENERATED_DIR, { recursive: true });
  await fs.writeFile(MANIFEST_PATH, `${JSON.stringify(manifest, null, 2)}\n`);
}

async function prune(cards, manifest, targeted) {
  if (targeted) return [];
  const desired = new Set(cards.map((card) => card.canonical));
  const removed = [];
  for (const [canonical, entry] of Object.entries(manifest.cards)) {
    if (desired.has(canonical)) continue;
    const outputRel = entry.output || outputRelative(canonical);
    await fs.unlink(path.join(GENERATED_DIR, outputRel)).catch((error) => { if (error.code !== 'ENOENT') throw error; });
    delete manifest.cards[canonical];
    removed.push(canonical);
  }
  for (const file of await orphanedAssets(cards)) {
    await fs.unlink(path.join(GENERATED_DIR, file));
    removed.push(`asset:${file}`);
  }
  return removed;
}

async function checkMetadata(cards) {
  const failures = [];
  for (const card of cards) {
    const decodedCanonical = decodeURIComponent(card.canonical);
    const htmlPath = decodedCanonical === '/' ? path.join(PUBLIC_DIR, 'index.html') : path.join(PUBLIC_DIR, decodedCanonical, 'index.html');
    try {
      const html = await fs.readFile(htmlPath, 'utf8');
      const expected = `/images/og/generated/${card.outputRel}`;
      if (card.metadataEnabled && !html.includes(expected)) {
        failures.push(`${card.canonical}: metadata does not reference ${expected}`);
      } else if (!card.metadataEnabled && html.includes(expected)) {
        failures.push(`${card.canonical}: generated metadata is disabled but references ${expected}`);
      }
    } catch (error) { failures.push(`${card.canonical}: page HTML missing (${error.message})`); }
  }
  return failures;
}

async function main() {
  const opts = parseOgArgs(process.argv.slice(2));
  if (!opts.skipBuild) build();
  const cards = await discoverCards(opts);
  const manifest = await readManifest();
  const problems = await statusFor(cards, manifest);

  if (opts.check) {
    const desired = new Set(cards.map((card) => card.canonical));
    const orphans = (opts.only || opts.section) ? [] : Object.keys(manifest.cards).filter((key) => !desired.has(key));
    const assetOrphans = (opts.only || opts.section) ? [] : await orphanedAssets(cards);
    const metadata = await checkMetadata(cards.filter((card) => !problems.some((p) => p.card.canonical === card.canonical)));
    for (const problem of problems) console.error(`✗ ${problem.card.canonical} — ${problem.reason}`);
    for (const orphan of orphans) console.error(`✗ ${orphan} — orphaned generated card`);
    for (const orphan of assetOrphans) console.error(`✗ ${orphan} — orphaned generated image file`);
    for (const failure of metadata) console.error(`✗ ${failure}`);
    if (problems.length || orphans.length || assetOrphans.length || metadata.length) throw new Error(`${problems.length + orphans.length + assetOrphans.length + metadata.length} OG card problem(s); run npm run og:generate`);
    console.log(`✓ ${cards.length} OG cards are current, valid, and referenced`);
    return;
  }

  const stale = opts.force ? cards : problems.map((problem) => problem.card);
  const removed = await prune(cards, manifest, Boolean(opts.only || opts.section));
  if (removed.length) console.log(`› pruned ${removed.length} orphaned card(s)`);
  if (stale.length === 0) {
    await writeManifest(manifest);
    console.log(`✓ ${cards.length} cards already current`);
    return;
  }

  console.log(`› rendering ${stale.length} of ${cards.length} card(s) with ${opts.jobs} worker(s)`);
  const { chromium } = await loadPlaywright();
  const { server, port } = await serve();
  const browser = await launchChromium(chromium);
  const context = await browser.newContext({ viewport: { width: WIDTH, height: HEIGHT }, deviceScaleFactor: 1 });
  if (opts.stubTiles) {
    const tile = Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGN4dv8SAAVGApjzYKUrAAAAAElFTkSuQmCC', 'base64');
    await context.route((url) => ['basemap.nationalmap.gov', 'tile.openstreetmap.org'].includes(url.hostname), (route) => route.fulfill({ status: 200, contentType: 'image/png', body: tile }));
  }
  let cursor = 0;
  let completed = 0;
  const failures = [];
  const workers = Array.from({ length: Math.min(opts.jobs, stale.length) }, async () => {
    const page = await context.newPage();
    while (true) {
      const index = cursor++;
      if (index >= stale.length) break;
      const card = stale[index];
      try {
        await shoot(page, port, card, opts.stubTiles);
        manifest.cards[card.canonical] = { output: card.outputRel, fingerprint: card.fingerprint, layout: card.layout, section: card.section };
        completed++;
        if (completed % 50 === 0 || completed === stale.length) console.log(`  ${completed}/${stale.length}`);
      } catch (error) {
        failures.push(`${card.canonical}: ${error.message}`);
        console.error(`✗ ${card.canonical} — ${error.message}`);
      }
    }
    await page.close();
  });
  await Promise.all(workers);
  await browser.close();
  await new Promise((resolve) => server.close(resolve));
  await writeManifest(manifest);
  console.log(`› wrote ${completed} card(s)`);
  if (failures.length) throw new Error(`${failures.length} card(s) failed; successful cards were retained and the next run will resume`);

  build();
  const rebuilt = await discoverCards(opts);
  const remaining = await statusFor(rebuilt, manifest);
  const metadataFailures = await checkMetadata(rebuilt);
  if (remaining.length || metadataFailures.length) throw new Error(`post-generation verification failed (${remaining.length} stale, ${metadataFailures.length} metadata)`);
  console.log(`✓ ${rebuilt.length} cards generated and verified`);
}

main().catch((error) => { console.error(`\n✗ ${error.message}`); process.exitCode = 1; });
