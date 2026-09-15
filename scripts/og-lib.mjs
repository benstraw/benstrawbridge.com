import { createHash } from 'node:crypto';
import path from 'node:path';

export const WIDTH = 1200;
export const HEIGHT = 630;
export const JPEG_QUALITY = 84;
export const RENDERER_VERSION = 1;

export function parseOgArgs(argv) {
  const opts = { check: false, force: false, only: null, onlyPaths: [], section: null, skipBuild: false, stubTiles: false, jobs: 4 };
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (arg === '--check') opts.check = true;
    else if (arg === '--force') opts.force = true;
    else if (arg === '--only') {
      const canonical = normalizeCanonical(argv[++i]);
      opts.only ??= canonical;
      opts.onlyPaths.push(canonical);
    }
    else if (arg === '--section') opts.section = argv[++i];
    else if (arg === '--skip-build') opts.skipBuild = true;
    else if (arg === '--stub-tiles') opts.stubTiles = true;
    else if (arg === '--jobs') opts.jobs = Number(argv[++i]);
    else throw new Error(`unknown argument: ${arg}`);
  }
  if (!Number.isInteger(opts.jobs) || opts.jobs < 1 || opts.jobs > 16) throw new Error('--jobs must be an integer from 1 to 16');
  return opts;
}

export function matchesFilters(card, opts) {
  const onlyPaths = opts.onlyPaths?.length ? opts.onlyPaths : (opts.only ? [opts.only] : []);
  return (!onlyPaths.length || onlyPaths.includes(card.canonical)) && (!opts.section || card.section === opts.section);
}

export function isEligibleCard({ filePath = '', type = '', kind = '', section = '', canonical = '/', ogGenerate = true, ogImage = '' }) {
  const authored = filePath.endsWith('.md');
  const generatedMusic = type === 'listening-artist' || type === 'listening-weekly' || (kind === 'term' && section === 'musical-genres');
  const legacyTrail = section === 'trails' && ogImage === 'og-cover.jpg';
  return (authored || generatedMusic) && !canonical.includes('/test/') && ogGenerate !== false && (!ogImage || legacyTrail);
}

export function selectSourcePriority({ ogSourceImage, headerImage, isSectionRoot = false, featuredImage, images = [], cardImage, namedResource, contentImage } = {}) {
  return [ogSourceImage, isSectionRoot ? headerImage : null, featuredImage, images[0], cardImage, namedResource, contentImage].find(Boolean) || null;
}

export function selectMetadataImage({ manual, generated, fallback } = {}) {
  return manual || generated || fallback || null;
}

export function classifyManifest(cards, manifestCards, existingOutputs) {
  const missing = [];
  const stale = [];
  for (const card of cards) {
    const entry = manifestCards[card.canonical];
    if (!entry || !existingOutputs.has(card.outputRel)) missing.push(card.canonical);
    else if (entry.fingerprint !== card.fingerprint) stale.push(card.canonical);
  }
  const desired = new Set(cards.map((card) => card.canonical));
  const orphaned = Object.keys(manifestCards).filter((canonical) => !desired.has(canonical));
  return { missing, stale, orphaned };
}

export function normalizeCanonical(value) {
  if (!value) throw new Error('canonical path is required');
  const parsed = value.startsWith('http://') || value.startsWith('https://')
    ? new URL(value).pathname
    : value;
  let normalized = `/${parsed}`.replace(/\/{2,}/g, '/');
  if (!normalized.endsWith('/')) normalized += '/';
  return normalized;
}

export function outputRelative(canonical) {
  const normalized = normalizeCanonical(canonical);
  if (normalized === '/') return 'home.jpg';
  return `${normalized.slice(1, -1)}.jpg`;
}

export function fingerprintHtml(html) {
  // Hugo injects its own version into the home-page document. That metadata
  // does not affect the screenshot, and local/Amplify Hugo patch versions can
  // differ, so exclude it from the visual freshness fingerprint.
  const visualHtml = html.replace(/<meta\s+name=["']generator["']\s+content=["']Hugo\s+[^"']+["']\s*\/?>\s*/gi, '');
  const renderer = JSON.stringify({
    width: WIDTH,
    height: HEIGHT,
    quality: JPEG_QUALITY,
    rendererVersion: RENDERER_VERSION,
  });
  return createHash('sha256').update(renderer).update('\0').update(visualHtml).digest('hex');
}

export function parseCardDocument(html, sourceFile) {
  const match = html.match(/<div id="og-card"([^>]*)>/);
  if (!match) throw new Error(`${sourceFile}: missing #og-card`);
  const attributes = {};
  for (const attr of match[1].matchAll(/\s(data-og-[\w-]+)="([^"]*)"/g)) {
    attributes[attr[1].slice(8)] = attr[2]
      .replaceAll('&amp;', '&')
      .replaceAll('&#34;', '"')
      .replaceAll('&#39;', "'");
  }
  const eligible = attributes.eligible === 'true';
  if (eligible && !attributes.canonical) {
    throw new Error(`${sourceFile}: eligible card is missing data-og-canonical`);
  }
  return {
    eligible,
    canonical: attributes.canonical ? normalizeCanonical(attributes.canonical) : null,
    section: attributes.section || '',
    layout: attributes.layout || '',
    source: attributes.source || '',
  };
}

export function jpegDimensions(buffer) {
  if (buffer.length < 4 || buffer[0] !== 0xff || buffer[1] !== 0xd8) {
    throw new Error('not a JPEG');
  }
  let offset = 2;
  while (offset + 8 < buffer.length) {
    if (buffer[offset] !== 0xff) {
      offset++;
      continue;
    }
    const marker = buffer[offset + 1];
    offset += 2;
    if (marker === 0xd8 || marker === 0xd9) continue;
    if (offset + 2 > buffer.length) break;
    const length = buffer.readUInt16BE(offset);
    if (length < 2 || offset + length > buffer.length) break;
    if (
      (marker >= 0xc0 && marker <= 0xc3) ||
      (marker >= 0xc5 && marker <= 0xc7) ||
      (marker >= 0xc9 && marker <= 0xcb) ||
      (marker >= 0xcd && marker <= 0xcf)
    ) {
      return {
        height: buffer.readUInt16BE(offset + 3),
        width: buffer.readUInt16BE(offset + 5),
      };
    }
    offset += length;
  }
  throw new Error('JPEG dimensions not found');
}

export function classifyLayout(width, height, override = 'auto') {
  if (override !== 'auto') return override;
  if (!width || !height) return 'abstract';
  return width / height >= 1.35 ? 'full' : 'split';
}

export function outputAbsolute(root, canonical) {
  return path.join(root, outputRelative(canonical));
}
