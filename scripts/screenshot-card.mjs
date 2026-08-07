#!/usr/bin/env node
/*
 * Photograph a web page at card proportions, for use as a `cardImage`.
 *
 * layouts/partials/card-image.html crops whatever it is given to 16:9 with
 * `object-top`, so a tall page screenshot loses most of its height. This takes
 * the shot at 16:9 in the first place: the browser viewport is the crop, which
 * means what you see in the file is what the card shows.
 *
 * Unlike generate-trail-og.mjs this touches no front matter and builds nothing.
 * It writes one image. Pointing a page at it — `cardImage` in front matter — is
 * a separate, deliberate step.
 *
 * Needs the target reachable from the machine it runs on. Claude Code on the
 * web denies most origins at the proxy (`CONNECT tunnel failed, 403`) and
 * resets map-tile CDNs even when the origin is allowed, so a card of anything
 * with a live map has to be shot locally. See CLAUDE.md.
 *
 * Usage:
 *   npm run card:shot -- --url https://example.com/ --out content/projects/x/card.jpg
 *   npm run card:shot -- --url … --out … --width 1920 --height 1080
 *   npm run card:shot -- --url … --out … --wait '.hero-map'   # settle on a selector
 *   npm run card:shot -- --url … --out … --delay 5000         # slow hero animation
 *   npm run card:shot -- --url … --out … --allow-blank        # skip the image guard
 *
 * Output format follows the extension: .jpg/.jpeg → JPEG q88, .png → PNG.
 * Prefer JPEG for photographic pages (maps, screenshots with imagery); PNG for
 * flat-colour pages with text and line art. Hugo re-encodes to WebP either way,
 * so this choice only decides what the repo carries.
 */

import { existsSync } from 'node:fs';
import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const REPO_ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
/* Same escape hatch generate-trail-og.mjs uses: the container ships one
   Chromium under PLAYWRIGHT_BROWSERS_PATH and npm may resolve a playwright
   that wants a different build. This symlink sidesteps the version registry. */
const PREINSTALLED_CHROMIUM = '/opt/pw-browsers/chromium';
const DEFAULT_WIDTH = 1600;
const DEFAULT_HEIGHT = 900;
/* Headroom over the 1200w largest variant card-image.html generates, without
   carrying a needlessly large original in git. */
const JPEG_QUALITY = 88;
const NAV_TIMEOUT_MS = 45_000;
const DEFAULT_DELAY_MS = 2_000;

function parseArgs(argv) {
  const opts = {
    url: null,
    out: null,
    width: DEFAULT_WIDTH,
    height: DEFAULT_HEIGHT,
    wait: null,
    delay: DEFAULT_DELAY_MS,
    allowBlank: false,
  };
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (arg === '--url') opts.url = argv[++i];
    else if (arg === '--out') opts.out = argv[++i];
    else if (arg === '--width') opts.width = Number(argv[++i]);
    else if (arg === '--height') opts.height = Number(argv[++i]);
    else if (arg === '--wait') opts.wait = argv[++i];
    else if (arg === '--delay') opts.delay = Number(argv[++i]);
    else if (arg === '--allow-blank') opts.allowBlank = true;
    else throw new Error(`unknown argument: ${arg}`);
  }

  if (!opts.url) throw new Error('--url is required');
  if (!opts.out) throw new Error('--out is required');
  for (const key of ['width', 'height', 'delay']) {
    if (!Number.isFinite(opts[key]) || opts[key] < 0) {
      throw new Error(`--${key} needs a number`);
    }
  }

  const ext = path.extname(opts.out).toLowerCase();
  if (!['.jpg', '.jpeg', '.png'].includes(ext)) {
    throw new Error(`--out must end in .jpg, .jpeg or .png (got ${ext || 'no extension'})`);
  }
  opts.type = ext === '.png' ? 'png' : 'jpeg';
  opts.out = path.resolve(REPO_ROOT, opts.out);
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

/* Try the browser playwright expects first, and only reach for the container's
 * preinstalled one when that is genuinely absent — same reasoning as
 * generate-trail-og.mjs, so a Chromium bump in the image keeps working.
 */
async function launchChromium(chromium) {
  /* Chromium does not pick up HTTPS_PROXY the way curl does; left alone in a
     proxied sandbox its requests hang rather than fail. Unset on a normal
     machine, so this is a no-op there. Loopback is bypassed so a locally
     served target stays reachable. */
  const proxyServer = process.env.HTTPS_PROXY || process.env.https_proxy;
  const opts = proxyServer
    ? { proxy: { server: proxyServer, bypass: '127.0.0.1,localhost,::1' } }
    : {};

  try {
    return await chromium.launch(opts);
  } catch (err) {
    if (!existsSync(PREINSTALLED_CHROMIUM)) throw err;
    console.warn(`› playwright's own browser is missing; using ${PREINSTALLED_CHROMIUM}`);
    return chromium.launch({ ...opts, executablePath: PREINSTALLED_CHROMIUM });
  }
}

async function main() {
  const opts = parseArgs(process.argv.slice(2));
  const { chromium } = await loadPlaywright();
  const browser = await launchChromium(chromium);

  /* The blank-card guard. generate-trail-og.mjs learned this the hard way:
     when tile requests hang rather than error, the page looks "loaded" and you
     ship a photograph of an empty map without noticing. Counting images that
     actually arrived turns that silence into a failure. */
  let imagesLoaded = 0;
  let imagesFailed = 0;

  try {
    const page = await browser.newPage({
      viewport: { width: opts.width, height: opts.height },
    });

    page.on('response', (res) => {
      if (res.request().resourceType() !== 'image') return;
      if (res.status() < 400) imagesLoaded++;
      else imagesFailed++;
    });
    page.on('requestfailed', (req) => {
      if (req.resourceType() === 'image') imagesFailed++;
    });

    console.log(`› ${opts.url} at ${opts.width}x${opts.height}`);
    const response = await page.goto(opts.url, {
      waitUntil: 'networkidle',
      timeout: NAV_TIMEOUT_MS,
    });
    if (response && response.status() >= 400) {
      throw new Error(`${opts.url} returned HTTP ${response.status()}`);
    }

    if (opts.wait) {
      await page.waitForSelector(opts.wait, { timeout: NAV_TIMEOUT_MS });
    }
    if (opts.delay) {
      await page.waitForTimeout(opts.delay);
    }

    if (imagesLoaded === 0 && !opts.allowBlank) {
      throw new Error(
        `no images loaded (${imagesFailed} failed) — the page probably rendered ` +
          'blank. Map tiles and CDN assets are commonly blocked in a sandbox; ' +
          'run this on a real machine, or pass --allow-blank if the page is ' +
          'genuinely image-free.'
      );
    }

    await fs.mkdir(path.dirname(opts.out), { recursive: true });
    await page.screenshot({
      path: opts.out,
      type: opts.type,
      ...(opts.type === 'jpeg' ? { quality: JPEG_QUALITY } : {}),
    });

    const { size } = await fs.stat(opts.out);
    const rel = path.relative(REPO_ROOT, opts.out);
    console.log(
      `› wrote ${rel} (${Math.round(size / 1024)}KB, ` +
        `${imagesLoaded} image(s) loaded, ${imagesFailed} failed)`
    );
    console.log(`› point a page at it with: cardImage = "${path.basename(opts.out)}"`);
  } finally {
    await browser.close();
  }
}

main().catch((err) => {
  console.error(`✗ ${err.message}`);
  process.exit(1);
});
