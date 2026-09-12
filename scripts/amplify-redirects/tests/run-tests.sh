#!/usr/bin/env bash
# Exercises scripts/amplify-redirects/check.sh against a mock `aws`, so the
# validators and the live-vs-declared diff can be changed without an AWS
# account. Run it as `npm run test:amplify-redirects`.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "${HERE}/../../.." && pwd)"
CHECK="${REPO_ROOT}/scripts/amplify-redirects/check.sh"
PASS=0; FAIL=0

check() { # check <description> <expected> <actual>
  if [[ "$2" == "$3" ]]; then PASS=$((PASS+1)); printf '  ✓ %s\n' "$1"
  else FAIL=$((FAIL+1)); printf '  ✗ %s (expected %q, got %q)\n' "$1" "$2" "$3"; fi
}
contains() { if grep -qF -- "$2" <<<"$1"; then echo yes; else echo no; fi; }

export PATH="${HERE}/mockbin:$PATH"
export AMPLIFY_APP_ID=d1abcdefghij AWS_REGION=us-west-2
MOCK_STATE="$(mktemp -d)"; export MOCK_STATE
cd "$REPO_ROOT"

# Swap in a fixture rule file, restoring the real one on exit.
REAL="${REPO_ROOT}/amplify-redirects.json"
BACKUP="$(mktemp)"; cp "$REAL" "$BACKUP"
restore() { cp "$BACKUP" "$REAL"; rm -f "$BACKUP"; rm -rf "$MOCK_STATE"; }
trap restore EXIT

fixture() { # fixture <rules-json-array>
  jq -n --argjson r "$1" '{"$comment":["test fixture"],"rules":$r}' >"$REAL"
}
live() { echo "$1" >"$MOCK_STATE/custom_rules.json"; }

SIMPLE='[{"source":"/a/","target":"/b/","status":"301"}]'

echo "── 1. The declared file in the repo is valid"
cp "$BACKUP" "$REAL"
out="$("$CHECK" --print 2>&1)"; rc=$?
check "real amplify-redirects.json passes validation" 0 "$rc"
check "emits a bare array, annotations stripped" no "$(contains "$out" '$why')"

echo "── 2. Validators reject malformed rules"
fixture '[{"source":"no-slash/","target":"/b/","status":"301"}]'
out="$("$CHECK" --print 2>&1)"; check "missing leading slash is rejected" 1 "$?"
check "  …and says why" yes "$(contains "$out" 'must start with')"

fixture '[{"source":"/a/","target":"/b/","status":"307"}]'
"$CHECK" --print >/dev/null 2>&1; check "unsupported status is rejected" 1 "$?"

fixture '[{"source":"/a/<*>","target":"/b/","status":"301"}]'
out="$("$CHECK" --print 2>&1)"; check "wildcard collapsing to one URL is rejected" 1 "$?"
check "  …and explains the collapse" yes "$(contains "$out" 'collapse')"

fixture '[{"source":"/a/:splat","target":"/b/:splat","status":"301"}]'
out="$("$CHECK" --print 2>&1)"; check "Netlify :splat syntax is rejected" 1 "$?"
check "  …and names the Amplify syntax" yes "$(contains "$out" '<*>')"

echo "── 3. Live comparison"
fixture "$SIMPLE"; live "$SIMPLE"
out="$("$CHECK" 2>&1)"; check "matching rules exit 0" 0 "$?"
check "  …and say so" yes "$(contains "$out" 'already match')"

fixture "$SIMPLE"; live '[]'
out="$("$CHECK" 2>&1)"; check "drift exits non-zero" 1 "$?"
check "  …and prints the apply command" yes "$(contains "$out" 'aws amplify update-app')"
check "  …with --custom-rules pointing at a file" yes "$(contains "$out" '--custom-rules file://')"

# The dangerous case: applying REPLACES everything, so a rule that exists live
# but is not declared gets silently deleted. It must be called out.
fixture "$SIMPLE"
live '[{"source":"/a/","target":"/b/","status":"301"},{"source":"/keep/","target":"/kept/","status":"301"}]'
out="$("$CHECK" 2>&1)"
check "warns that an undeclared live rule would be deleted" yes "$(contains "$out" 'DELETE')"
check "  …and names the rule at risk" yes "$(contains "$out" '/keep/')"

echo ""
if (( FAIL )); then echo "${PASS} passed, ${FAIL} failed"; exit 1; fi
echo "${PASS} passed, 0 failed"
