import assert from 'node:assert/strict';
import test from 'node:test';
import {
  HEIGHT,
  WIDTH,
  classifyLayout,
  classifyManifest,
  fingerprintHtml,
  isEligibleCard,
  jpegDimensions,
  matchesFilters,
  normalizeCanonical,
  outputRelative,
  parseOgArgs,
  selectMetadataImage,
  selectSourcePriority,
} from './og-lib.mjs';

test('canonical paths and outputs are deterministic', () => {
  assert.equal(normalizeCanonical('posts/example'), '/posts/example/');
  assert.equal(normalizeCanonical('https://example.com/posts/example/'), '/posts/example/');
  assert.equal(outputRelative('/'), 'home.jpg');
  assert.equal(outputRelative('/posts/example/'), 'posts/example.jpg');
});

test('layout selection follows image shape', () => {
  assert.equal(classifyLayout(0, 0), 'abstract');
  assert.equal(classifyLayout(1600, 900), 'full');
  assert.equal(classifyLayout(640, 640), 'split');
  assert.equal(classifyLayout(640, 640, 'full'), 'full');
});

test('eligibility includes authored and generated music while honoring exclusions', () => {
  assert.equal(isEligibleCard({ filePath: 'posts/a/index.md', canonical: '/posts/a/' }), true);
  assert.equal(isEligibleCard({ type: 'listening-weekly', canonical: '/listening/weekly/2026-w01/' }), true);
  assert.equal(isEligibleCard({ kind: 'term', section: 'musical-genres', canonical: '/musical-genres/rock/' }), true);
  assert.equal(isEligibleCard({ filePath: 'posts/test/a.md', canonical: '/posts/test/a/' }), false);
  assert.equal(isEligibleCard({ filePath: 'posts/a.md', canonical: '/posts/a/', ogGenerate: false }), false);
  assert.equal(isEligibleCard({ filePath: 'posts/a.md', canonical: '/posts/a/', ogImage: 'custom.jpg' }), false);
  assert.equal(isEligibleCard({ filePath: 'trails/a/index.md', canonical: '/trails/a/', section: 'trails', ogImage: 'og-cover.jpg' }), true);
});

test('source selection uses the documented priority', () => {
  const values = { ogSourceImage: 'explicit.jpg', headerImage: 'header.jpg', isSectionRoot: true, featuredImage: 'feature.jpg', images: ['first.jpg'], cardImage: 'card.jpg', namedResource: 'cover.jpg', contentImage: 'body.jpg' };
  assert.equal(selectSourcePriority(values), 'explicit.jpg');
  assert.equal(selectSourcePriority({ ...values, ogSourceImage: null }), 'header.jpg');
  assert.equal(selectSourcePriority({ ...values, ogSourceImage: null, isSectionRoot: false }), 'feature.jpg');
  assert.equal(selectSourcePriority({ ...values, ogSourceImage: null, isSectionRoot: false, featuredImage: null }), 'first.jpg');
  assert.equal(selectSourcePriority({ cardImage: 'card.jpg', namedResource: 'cover.jpg' }), 'card.jpg');
});

test('manual metadata overrides generated artwork and fallback', () => {
  assert.equal(selectMetadataImage({ manual: 'manual.jpg', generated: 'generated.jpg', fallback: 'fallback.jpg' }), 'manual.jpg');
  assert.equal(selectMetadataImage({ generated: 'generated.jpg', fallback: 'fallback.jpg' }), 'generated.jpg');
  assert.equal(selectMetadataImage({ generated: 'generated.jpg', fallback: 'fallback.jpg', generatedEnabled: false }), 'fallback.jpg');
  assert.equal(selectMetadataImage({ manual: 'manual.jpg', generated: 'generated.jpg', fallback: 'fallback.jpg', generatedEnabled: false }), 'manual.jpg');
});

test('manifest classification finds missing, stale, and orphaned cards', () => {
  const cards = [
    { canonical: '/a/', outputRel: 'a.jpg', fingerprint: 'new-a' },
    { canonical: '/b/', outputRel: 'b.jpg', fingerprint: 'new-b' },
  ];
  const result = classifyManifest(cards, {
    '/a/': { output: 'a.jpg', fingerprint: 'old-a' },
    '/orphan/': { output: 'orphan.jpg', fingerprint: 'x' },
  }, new Set(['a.jpg']));
  assert.deepEqual(result, { missing: ['/b/'], stale: ['/a/'], orphaned: ['/orphan/'] });
});

test('CLI filters normalize paths and select exact page or section', () => {
  const page = parseOgArgs(['--only', 'posts/a', '--only', '/posts/b/', '--force', '--jobs', '2']);
  assert.equal(page.only, '/posts/a/');
  assert.deepEqual(page.onlyPaths, ['/posts/a/', '/posts/b/']);
  assert.equal(page.force, true);
  assert.equal(page.jobs, 2);
  assert.equal(matchesFilters({ canonical: '/posts/a/', section: 'posts' }, page), true);
  assert.equal(matchesFilters({ canonical: '/posts/b/', section: 'posts' }, page), true);
  assert.equal(matchesFilters({ canonical: '/posts/c/', section: 'posts' }, page), false);
  const section = parseOgArgs(['--section', 'trails']);
  assert.equal(matchesFilters({ canonical: '/trails/a/', section: 'trails' }, section), true);
  assert.throws(() => parseOgArgs(['--wat']), /unknown argument/);
});

test('render fingerprints change with rendered inputs', () => {
  assert.equal(fingerprintHtml('<p>a</p>'), fingerprintHtml('<p>a</p>'));
  assert.notEqual(fingerprintHtml('<p>a</p>'), fingerprintHtml('<p>b</p>'));
});

test('render fingerprints ignore non-visual Hugo generator versions', () => {
  const local = '<!doctype html>\n<meta name="generator" content="Hugo 0.146.2">\n<p>card</p>';
  const amplify = '<!doctype html>\n<meta name="generator" content="Hugo 0.148.2">\n<p>card</p>';
  assert.equal(fingerprintHtml(local), fingerprintHtml(amplify));
});

test('metadata review gate does not stale the visual fingerprint', () => {
  const enabled = '<div id="og-card" data-og-metadata-enabled="true"><p>card</p></div>';
  const disabled = '<div id="og-card" data-og-metadata-enabled="false"><p>card</p></div>';
  assert.equal(fingerprintHtml(enabled), fingerprintHtml(disabled));
});

test('JPEG reader returns dimensions and rejects other files', () => {
  const jpeg = Buffer.from([
    0xff, 0xd8,
    0xff, 0xc0, 0x00, 0x11, 0x08,
    (HEIGHT >> 8) & 0xff, HEIGHT & 0xff,
    (WIDTH >> 8) & 0xff, WIDTH & 0xff,
    0x03, 0x01, 0x11, 0x00, 0x02, 0x11, 0x00, 0x03, 0x11, 0x00,
    0xff, 0xd9,
  ]);
  assert.deepEqual(jpegDimensions(jpeg), { width: WIDTH, height: HEIGHT });
  assert.throws(() => jpegDimensions(Buffer.from('nope')), /not a JPEG/);
});
