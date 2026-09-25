#!/usr/bin/env bash
# Exercises scripts/aws-teardown/teardown.sh against mock `aws` and `curl`, so
# it can be changed without an AWS account. Run it as `npm run test:aws-teardown`.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$(cd "${HERE}/.." && pwd)/teardown.sh"
PASS=0; FAIL=0

check() { # check <description> <expected> <actual>
  if [[ "$2" == "$3" ]]; then PASS=$((PASS+1)); printf '  ✓ %s\n' "$1"
  else FAIL=$((FAIL+1)); printf '  ✗ %s (expected %q, got %q)\n' "$1" "$2" "$3"; fi
}
has() { if grep -qE -- "$2" <<<"$1"; then echo yes; else echo no; fi; }
MUTATING='^[a-z0-9]+ (delete-|detach-|change-|update-|put-)'

export PATH="${HERE}/mockbin:$PATH"
export AMPLIFY_APP_ID=d1abc AWS_REGION=us-west-2
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
cd "$WORK"

reset() { rm -rf "$WORK/state" "$WORK/aws-teardown-backup"; mkdir -p "$WORK/state"; export MOCK_STATE="$WORK/state"; : >"$MOCK_STATE/calls"; }
calls() { cat "$MOCK_STATE/calls"; }

echo "── 1. Inventory mode is read-only"
reset
out="$("$SCRIPT" 2>&1 </dev/null)"; rc=$?
check "exits 0" 0 "$rc"
check "makes no mutating AWS call" no "$(has "$(calls)" "$MUTATING")"
check "lists the Amplify app" yes "$(has "$out" 'name: +benstrawbridge.com')"
check "lists the matching bucket only" "yes no" "$(has "$out" 'benstraw-site') $(has "$out" 'unrelated-bucket')"
check "lists only the domain's zone" "yes no" "$(has "$out" 'Z1 ') $(has "$out" 'Z2')"
check "backs up Amplify env vars and rules" yes \
  "$(jq -e '.app.environmentVariables and .app.customRules' aws-teardown-backup/*/amplify-app.json >/dev/null && echo yes || echo no)"

echo "── 2. Unset AMPLIFY_APP_ID lists apps and stops"
reset
out="$(AMPLIFY_APP_ID= "$SCRIPT" 2>&1 </dev/null)"; rc=$?
check "exits non-zero" 1 "$rc"
check "prints the app id" yes "$(has "$out" 'd1abc +benstrawbridge.com')"

echo "── 3. --apply refuses while CloudFront still serves the site"
reset; echo cloudfront >"$MOCK_STATE/serving"
out="$(echo benstrawbridge.com | "$SCRIPT" --apply 2>&1)"; rc=$?
check "exits non-zero" 1 "$rc"
check "makes no mutating AWS call" no "$(has "$(calls)" "$MUTATING")"
check "says to cut over first" yes "$(has "$out" 'Cut over first')"

echo "── 4. --apply refuses a wrong confirmation"
reset
out="$(echo nope | "$SCRIPT" --apply 2>&1)"; rc=$?
check "exits non-zero" 1 "$rc"
check "makes no mutating AWS call" no "$(has "$(calls)" "$MUTATING")"

echo "── 5. --apply with confirmations deletes in order"
reset
out="$(printf 'benstrawbridge.com\nbenstraw-site\n' | "$SCRIPT" --apply 2>&1)"; rc=$?
check "exits 0" 0 "$rc"
order="$(grep -oE "$MUTATING" "$MOCK_STATE/calls" | tr '\n' ' ')"
# The mock returns the same cert in both regions scanned, hence two acm deletes.
check "deletion order" \
  "amplify delete- amplify delete- iam delete- iam delete- iam delete- route53 change- route53 delete- acm delete- acm delete- s3api delete- s3api delete- " \
  "$order"
check "domain association before app" yes "$(has "$(calls)" 'delete-domain-association --app-id d1abc --domain-name benstrawbridge.com')"
check "zone deletion keeps apex NS/SOA out of the batch" no \
  "$(grep '^route53 change-resource-record-sets' "$MOCK_STATE/calls" | grep -qE '"Type":"(NS|SOA)"' && echo yes || echo no)"
check "only the unrelated-domain cert is spared" no "$(has "$(calls)" 'arn:cert-other')"
check "never deletes a CloudFront distribution" no "$(has "$(calls)" '^cloudfront (delete|update)-')"
check "prints CloudFront commands instead" yes "$(has "$out" 'aws cloudfront delete-distribution --id E1')"
check "never touches the unrelated bucket" no "$(has "$(calls)" 'unrelated-bucket')"

echo "── 6. A bucket is skipped unless its name is typed"
reset
printf 'benstrawbridge.com\nno\n' | "$SCRIPT" --apply >/dev/null 2>&1
check "bucket not deleted" no "$(has "$(calls)" '^s3api delete-')"

echo "── 7. Shared OIDC provider and Route 53 still on AWS are kept"
reset; touch "$MOCK_STATE/oidc-shared"; echo aws >"$MOCK_STATE/ns"
out="$(printf 'benstrawbridge.com\nno\n' | "$SCRIPT" --apply 2>&1)"
check "OIDC provider kept" no "$(has "$(calls)" 'delete-open-id-connect-provider')"
check "  …and says who uses it" yes "$(has "$out" 'also trusted by other-deployer')"
check "Route 53 zone kept" no "$(has "$(calls)" '^route53 (change|delete)-')"
check "  …and says why" yes "$(has "$out" 'SKIPPED: public NS')"

echo "── 8. App already gone"
reset; touch "$MOCK_STATE/no-app"
out="$(printf 'delete\nno\n' | "$SCRIPT" --apply 2>&1)"; rc=$?
check "exits 0" 0 "$rc"
check "no Amplify delete" no "$(has "$(calls)" '^amplify delete-')"
check "still deletes the IAM role" yes "$(has "$(calls)" '^iam delete-role --role-name github-amplify-preview')"

echo
echo "${PASS} passed, ${FAIL} failed"
[ "$FAIL" -eq 0 ]
