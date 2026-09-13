#!/usr/bin/env bash
#
# Compare the redirect rules declared in amplify-redirects.json against the ones
# the Amplify app is actually serving, and print the command to apply the
# difference.
#
# Read-only. Uses `aws amplify get-app`, which is the amplify:GetApp permission
# the preview role already holds — this script never writes. Applying is a
# deliberate manual step: `amplify:UpdateApp` also confers control of the build
# spec and environment variables, so it is not granted to CI.
#
#   ./scripts/amplify-redirects/check.sh                 # diff live vs declared
#   ./scripts/amplify-redirects/check.sh --print         # just emit the array
#
# Env: AMPLIFY_APP_ID (required unless --print), AWS_REGION (optional).

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
declared_file="${repo_root}/amplify-redirects.json"
print_only=0

for arg in "$@"; do
  case "$arg" in
    --print) print_only=1 ;;
    -h|--help) sed -n '2,18p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown argument: $arg" >&2; exit 2 ;;
  esac
done

command -v jq >/dev/null || { echo "jq is required" >&2; exit 1; }
[[ -f $declared_file ]] || { echo "missing ${declared_file}" >&2; exit 1; }

# Strip the $comment / $why annotations to get the array Amplify accepts. Key
# order is normalised so the diff below compares content, not formatting.
strip='[ .rules[] | {source, target, status} + (if .condition then {condition} else {} end) ]'

if ! declared="$(jq -e "$strip" "$declared_file" 2>/dev/null)"; then
  echo "amplify-redirects.json is not valid, or has no .rules array" >&2
  exit 1
fi

# Catch the mistakes that only surface as a broken production redirect.
errs=0
while IFS= read -r problem; do
  echo "  ✗ ${problem}" >&2
  errs=$((errs + 1))
done < <(jq -r '
  [ .rules[]
    | select((.source | startswith("/")) | not)
    | "source must start with \"/\": \(.source)"
  ] + [ .rules[]
    | select(.status | test("^(200|301|302|404|404-200)$") | not)
    | "status must be 200, 301, 302, 404 or 404-200: \(.source) -> \(.status)"
  ] + [ .rules[]
    | select((.source | test("<\\*>")) and ((.target | test("<\\*>")) | not))
    | "source has a <*> wildcard but target does not, so every match collapses to one URL: \(.source)"
  ] + [ .rules[]
    | select(.source | test(":splat"))
    | "Amplify uses <*>, not Netlify'"'"'s :splat: \(.source)"
  ] | .[]' "$declared_file")

if (( errs > 0 )); then
  echo "" >&2
  echo "${errs} problem(s) in amplify-redirects.json; not proceeding." >&2
  exit 1
fi

if (( print_only )); then
  echo "$declared"
  exit 0
fi

: "${AMPLIFY_APP_ID:?set AMPLIFY_APP_ID (or pass --print to skip the live comparison)}"
region_args=()
[[ -n ${AWS_REGION:-} ]] && region_args=(--region "$AWS_REGION")

live="$(aws amplify get-app --app-id "$AMPLIFY_APP_ID" "${region_args[@]}" \
  --query 'app.customRules' --output json \
  | jq '[ .[]? | {source, target, status} + (if .condition then {condition} else {} end) ]')"

out="$(mktemp -t amplify-redirects.XXXXXX.json)"
echo "$declared" > "$out"

if [[ "$(jq -S . <<<"$live")" == "$(jq -S . <<<"$declared")" ]]; then
  echo "✓ live rules already match amplify-redirects.json ($(jq length <<<"$declared") rule(s))"
  rm -f "$out"
  exit 0
fi

echo "Live rules differ from amplify-redirects.json."
echo ""
echo "--- live (${AMPLIFY_APP_ID})"
jq . <<<"$live"
echo ""
echo "+++ declared (amplify-redirects.json)"
jq . <<<"$declared"
echo ""
echo "Rules present live but NOT declared — applying will DELETE these:"
jq -e --argjson d "$declared" '[ .[] | select(. as $r | $d | index($r) | not) ]
  | if length == 0 then "  (none)" else (.[] | "  - \(.source) -> \(.target) [\(.status)]") end' \
  -r <<<"$live" || echo "  (none)"
echo ""
echo "To apply (replaces the whole rule set):"
echo ""
echo "  aws amplify update-app --app-id ${AMPLIFY_APP_ID}${AWS_REGION:+ --region ${AWS_REGION}} \\"
echo "    --custom-rules file://${out}"
echo ""
echo "Then re-run this script to confirm it took."
exit 1
