import { readFileSync, readdirSync, statSync } from 'node:fs'
import { join, resolve, relative } from 'node:path'

const ROOT = resolve(import.meta.dirname, '..')

function walkFiles(dir, exts, results = []) {
  for (const entry of readdirSync(dir)) {
    const full = join(dir, entry)
    if (statSync(full).isDirectory()) {
      if (entry === 'node_modules' || entry === 'public' || entry === '.git' || entry === 'themes') {
        continue
      }
      walkFiles(full, exts, results)
    } else if (exts.some(ext => full.endsWith(ext))) {
      results.push(full)
    }
  }
  return results
}

function toCamel(kebab, prefix = 'fa') {
  return prefix + kebab
    .replace(/^fa-/, '')
    .split('-')
    .map(word => word.charAt(0).toUpperCase() + word.slice(1))
    .join('')
}

function parseLibraryAdd(src) {
  const match = src.match(/library\.add\(([\s\S]*?)\)/g) || []
  const names = new Set()
  for (const block of match) {
    for (const token of block.split(/[\s,()]+/)) {
      const trimmed = token.trim()
      if (/^fa[rbs]?[A-Z]/.test(trimmed)) {
        names.add(trimmed)
      }
    }
  }
  return names
}

const themeMainJs = readFileSync(join(ROOT, 'themes/ryder/assets/js/main.js'), 'utf8')
const siteExtendedJs = readFileSync(join(ROOT, 'assets/js/extended.js'), 'utf8')
const importedIcons = new Set([
  ...parseLibraryAdd(themeMainJs),
  ...parseLibraryAdd(siteExtendedJs),
])

const scanDirs = [
  join(ROOT, 'layouts'),
  join(ROOT, 'content'),
  join(ROOT, 'config'),
  join(ROOT, 'data'),
]

const SOURCE_EXTS = ['.html', '.md', '.toml', '.json']
const patterns = [
  { re: /(?:fa-solid|fas)\s+fa-([\w-]+)/g, prefix: 'fa' },
  { re: /(?:fa-regular|far)\s+fa-([\w-]+)/g, prefix: 'far' },
  { re: /(?:fa-brands|fab)\s+fa-([\w-]+)/g, prefix: 'fa' },
]

const usedIcons = new Map()

for (const dir of scanDirs) {
  for (const file of walkFiles(dir, SOURCE_EXTS)) {
    const src = readFileSync(file, 'utf8')
    for (const { re, prefix } of patterns) {
      for (const [, name] of src.matchAll(re)) {
        const camel = toCamel(`fa-${name}`, prefix)
        if (!usedIcons.has(camel)) {
          usedIcons.set(camel, [])
        }
        usedIcons.get(camel).push(relative(ROOT, file))
      }
    }
  }
}

const missing = []
for (const [camel, files] of usedIcons) {
  if (!importedIcons.has(camel)) {
    missing.push({ camel, files })
  }
}

if (missing.length > 0) {
  const detail = missing
    .sort((a, b) => a.camel.localeCompare(b.camel))
    .map(({ camel, files }) => `  ${camel}  (${files[0]})`)
    .join('\n')

  console.error(
    `${missing.length} icon(s) used in benstrawbridge.com are not added to the FA library:\n${detail}\n` +
    'Add site-specific icons to assets/js/extended.js or remove the icon references.'
  )
  process.exit(1)
}

console.log(`FA audit passed: ${usedIcons.size} referenced icons are available.`)
