import assert from 'node:assert/strict'
import { execFileSync } from 'node:child_process'
import fs from 'node:fs'
import path from 'node:path'
import test from 'node:test'

const root = new URL('..', import.meta.url).pathname
const workflow = fs.readFileSync(path.join(root, '.github/workflows/posthog-deploy-annotation.yml'), 'utf8')

test('PostHog annotation workflow only marks successful production Workers Builds', () => {
  assert.match(workflow, /check_run:\n\s+types: \[completed\]/)
  assert.match(workflow, /Workers Builds: benstrawbridge-com/)
  assert.match(workflow, /check_run\.conclusion == 'success'/)
  assert.match(workflow, /compare\/\$DEFAULT_BRANCH\.\.\.\$SHA/)
  assert.match(workflow, /status" != "identical".*status" != "behind"/s)
})

test('PostHog annotation is pinned, deduplicated, and cannot fail a deploy', () => {
  assert.match(workflow, /continue-on-error: true/)
  assert.match(workflow, /PostHog\/posthog-github-action@[0-9a-f]{40}/)
  assert.match(workflow, /key="benstrawbridge\.com production deploy @ \$SHA"/)
  assert.match(workflow, /echo "content=\$key · \$subject · https:\/\/github\.com\/\$REPO\/commit\/\$SHA"/)
  assert.doesNotMatch(workflow, /\$\{SHA:0:7\}/)
  assert.match(workflow, /annotation-dedupe: true/)
  assert.match(workflow, /annotation-dedupe-key: \$\{\{ steps\.meta\.outputs\.dedupe_key \}\}/)
})

test('the CI-only personal key cannot reach the site', () => {
  assert.match(workflow, /permissions:\n\s+contents: read/)
  assert.match(workflow, /\$\{\{ secrets\.POSTHOG_CI_API_KEY \}\}/)
  for (const directory of ['assets', 'config', 'content', 'layouts', 'scripts', 'static']) {
    const command = `rg -n --glob '!posthog-deploy-annotation.test.mjs' 'POSTHOG_CI_API_KEY|\\bphx_[A-Za-z0-9]{10,}' ${directory}`
    const output = process.platform === 'win32' ? '' : requireNoMatches(command)
    assert.equal(output, '', `${directory} must not contain the CI key`)
  }
})

function requireNoMatches(command) {
  try {
    return execFileSync('sh', ['-c', command], { cwd: root, encoding: 'utf8' })
  } catch (error) {
    if (error.status === 1) return ''
    throw error
  }
}
