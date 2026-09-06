#!/usr/bin/env bash
# Exercises the on-demand Amplify preview scripts against mock aws/gh/curl
# binaries, so the deploy and cleanup logic can be changed without touching AWS
# or opening a throwaway pull request. Run it as `npm run test:amplify-preview`.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "${HERE}/../../.." && pwd)"
PASS=0; FAIL=0

setup() { # setup <existing-amplify-branches> <existing-git-branches> <job statuses...>
  MOCK_STATE="$(mktemp -d)"; export MOCK_STATE
  printf '%s' "$1" | tr ' ' '\n' | grep -v '^$' >"$MOCK_STATE/amplify_branches" || true
  printf '%s' "$2" | tr ' ' '\n' | grep -v '^$' >"$MOCK_STATE/git_branches" || true
  shift 2; printf '%s\n' "$@" >"$MOCK_STATE/job_statuses"
  : >"$MOCK_STATE/calls.log"; : >"$MOCK_STATE/comment_ops"
  echo "$HEAD_SHA" >"$MOCK_STATE/ref_sha"
  jq -n --arg d "${APP_DOMAIN:-d123abc.amplifyapp.com}" --arg p "${PROD_BRANCH:-main}" \
        --arg r "https://github.com/$GITHUB_REPOSITORY" --argjson ev "${APP_ENV:-{\}}" \
        --argjson auto "${APP_AUTO_CREATE:-false}" \
    '{app:{defaultDomain:$d, productionBranch:{branchName:$p}, repository:$r, platform:"WEB",
           enableAutoBranchCreation:$auto, autoBranchCreationPatterns:["release*"], environmentVariables:$ev}}' \
    >"$MOCK_STATE/app.json"
}

check() { # check <name> <condition-description> <expected> <actual>
  if [[ "$3" == "$4" ]]; then PASS=$((PASS+1)); printf '  ✓ %s\n' "$2"
  else FAIL=$((FAIL+1)); printf '  ✗ %s (expected %q, got %q)\n' "$2" "$3" "$4"; fi
}
contains() { if grep -qF -- "$2" <<<"$1"; then echo yes; else echo no; fi; }

export PATH="${HERE}/mockbin:$PATH"
export GITHUB_REPOSITORY="benstraw/benstrawbridge.com"
export GH_TOKEN=fake AWS_REGION=us-west-2 AMPLIFY_APP_ID=d1abcdefghij
export HEAD_SHA="1234567890abcdef1234567890abcdef12345678"
export RUN_URL="https://github.com/benstraw/benstrawbridge.com/actions/runs/1"
export POLL_INTERVAL_SECONDS=0 DEPLOY_TIMEOUT_SECONDS=60
export ENV_POLICY_FILE="$REPO_ROOT/.github/amplify-preview-env.json"
cd "$REPO_ROOT"

echo "── 1. First deployment: branch absent, build succeeds"
export PR_NUMBER=12
setup "" "" PENDING RUNNING SUCCEED
out="$(scripts/amplify-preview/deploy.sh 2>&1)"; rc=$?
check t1 "exits 0" 0 "$rc"
check t1 "creates the git branch" yes "$(contains "$(cat "$MOCK_STATE/calls.log")" 'POST repos/benstraw/benstrawbridge.com/git/refs')"
check t1 "creates the amplify branch" yes "$(contains "$(cat "$MOCK_STATE/calls.log")" 'create-branch')"
check t1 "disables auto build" yes "$(contains "$(cat "$MOCK_STATE/calls.log")" '--no-enable-auto-build')"
check t1 "sets PULL_REQUEST stage" yes "$(contains "$(cat "$MOCK_STATE/calls.log")" '--stage PULL_REQUEST')"
check t1 "disables native PR previews" yes "$(contains "$(cat "$MOCK_STATE/calls.log")" '--no-enable-pull-request-preview')"
check t1 "sets pr-12 display name" yes "$(contains "$(cat "$MOCK_STATE/calls.log")" '--display-name pr-12')"
check t1 "starts a RELEASE job" yes "$(contains "$(cat "$MOCK_STATE/calls.log")" 'start-job --app-id d1abcdefghij --branch-name amplify-preview/pr-12 --job-type RELEASE')"
check t1 "amplify branch tracks the git branch" yes "$(contains "$(cat "$MOCK_STATE/calls.log")" 'create-branch --app-id d1abcdefghij --branch-name amplify-preview/pr-12')"
check t1 "comment created once" "created" "$(cat "$MOCK_STATE/comment_ops" | head -1)"
check t1 "comment updated, not duplicated" "created patched" "$(tr '\n' ' ' <"$MOCK_STATE/comment_ops" | sed 's/ $//')"
check t1 "comment reports Ready" yes "$(contains "$(cat "$MOCK_STATE/comment_body.md")" 'Ready')"
check t1 "comment carries the preview URL" yes "$(contains "$(cat "$MOCK_STATE/comment_body.md")" 'https://pr-12.d123abc.amplifyapp.com')"
check t1 "comment carries the short SHA" yes "$(contains "$(cat "$MOCK_STATE/comment_body.md")" '1234567')"
check t1 "comment carries the marker" yes "$(contains "$(cat "$MOCK_STATE/comment_body.md")" '<!-- amplify-on-demand-preview -->')"
check t1 "comment carries the run link" yes "$(contains "$(cat "$MOCK_STATE/comment_body.md")" 'actions/runs/1')"

echo "── 2. Re-deploy: branch exists, ref force-updated, same URL"
setup "amplify-preview/pr-12" "amplify-preview/pr-12" SUCCEED
export HEAD_SHA="fedcba0987654321fedcba0987654321fedcba09"
out="$(scripts/amplify-preview/deploy.sh 2>&1)"; rc=$?
check t2 "exits 0" 0 "$rc"
check t2 "force-updates the existing ref" yes "$(contains "$(cat "$MOCK_STATE/calls.log")" 'PATCH repos/benstraw/benstrawbridge.com/git/refs/heads/amplify-preview/pr-12')"
check t2 "does not re-create the git ref" no "$(contains "$(cat "$MOCK_STATE/calls.log")" 'POST repos/benstraw/benstrawbridge.com/git/refs ')"
check t2 "converges the existing amplify branch" yes "$(contains "$(cat "$MOCK_STATE/calls.log")" 'update-branch')"
check t2 "does not call create-branch" no "$(contains "$(cat "$MOCK_STATE/calls.log")" 'create-branch')"
check t2 "same preview URL" yes "$(contains "$(cat "$MOCK_STATE/comment_body.md")" 'https://pr-12.d123abc.amplifyapp.com')"
check t2 "reports the new SHA" yes "$(contains "$(cat "$MOCK_STATE/comment_body.md")" 'fedcba0')"
export HEAD_SHA="1234567890abcdef1234567890abcdef12345678"

echo "── 3. Amplify job fails"
setup "" "" PENDING FAILED
out="$(scripts/amplify-preview/deploy.sh 2>&1)"; rc=$?
check t3 "workflow fails" 1 "$rc"
check t3 "comment reports Failed" yes "$(contains "$(cat "$MOCK_STATE/comment_body.md")" 'Failed')"
check t3 "comment links the amplify job" yes "$(contains "$(cat "$MOCK_STATE/comment_body.md")" 'console.aws.amazon.com/amplify/apps/d1abcdefghij')"

echo "── 4. Job cancelled / times out"
setup "" "" PENDING CANCELLED
out="$(scripts/amplify-preview/deploy.sh 2>&1)"; rc=$?
check t4 "cancelled job fails the workflow" 1 "$rc"
setup "" "" RUNNING; DEPLOY_TIMEOUT_SECONDS=0 out="$(scripts/amplify-preview/deploy.sh 2>&1)"; rc=$?
check t4 "timeout fails the workflow" 1 "$rc"
check t4 "timeout is explained" yes "$(contains "$out" 'did not finish within')"

echo "── 5. Unaudited app environment variable blocks the deployment"
APP_ENV='{"SECRET_TOKEN":"x","_LIVE_UPDATES":"y"}' setup "" "" SUCCEED
out="$(scripts/amplify-preview/deploy.sh 2>&1)"; rc=$?
check t5 "exits non-zero" 1 "$rc"
check t5 "names the unaudited variable" yes "$(contains "$out" 'SECRET_TOKEN')"
check t5 "creates no amplify branch" no "$(contains "$(cat "$MOCK_STATE/calls.log")" 'create-branch')"
check t5 "creates no git branch" no "$(contains "$(cat "$MOCK_STATE/calls.log")" 'git/refs')"
check t5 "starts no job" no "$(contains "$(cat "$MOCK_STATE/calls.log")" 'start-job')"

echo "── 6. Audited-only variables are allowed through"
APP_ENV='{"_LIVE_UPDATES":"y"}' setup "" "" SUCCEED
out="$(scripts/amplify-preview/deploy.sh 2>&1)"; rc=$?
check t6 "exits 0" 0 "$rc"

echo "── 7. Production safeguards"
PROD_BRANCH="amplify-preview/pr-12" setup "" "" SUCCEED
out="$(scripts/amplify-preview/deploy.sh 2>&1)"; rc=$?
check t7 "refuses to touch the production branch" 1 "$rc"
APP_AUTO_CREATE=true setup "" "" SUCCEED
out="$(scripts/amplify-preview/deploy.sh 2>&1)"; rc=$?
check t7 "tolerates auto-creation when no pattern matches" 0 "$rc"
setup "" "" SUCCEED
export GITHUB_REPOSITORY="someone/other-repo"
out="$(scripts/amplify-preview/deploy.sh 2>&1)"; rc=$?
check t7 "refuses an app wired to another repo" 1 "$rc"
export GITHUB_REPOSITORY="benstraw/benstrawbridge.com"

echo "── 8. Cleanup with both resources present"
setup "amplify-preview/pr-12" "amplify-preview/pr-12" SUCCEED
: >"$MOCK_STATE/comment_body.md"; echo '<!-- amplify-on-demand-preview -->' >"$MOCK_STATE/comment_body.md"
out="$(scripts/amplify-preview/cleanup.sh 2>&1)"; rc=$?
check t8 "exits 0" 0 "$rc"
check t8 "deletes the amplify branch" yes "$(contains "$(cat "$MOCK_STATE/calls.log")" 'delete-branch --app-id d1abcdefghij --branch-name amplify-preview/pr-12')"
check t8 "deletes the git branch" yes "$(contains "$(cat "$MOCK_STATE/calls.log")" 'DELETE repos/benstraw/benstrawbridge.com/git/refs/heads/amplify-preview/pr-12')"
check t8 "marks the comment removed" yes "$(contains "$(cat "$MOCK_STATE/comment_body.md")" 'Removed')"

echo "── 9. Cleanup when nothing exists (idempotent re-run)"
setup "" "" SUCCEED
out="$(scripts/amplify-preview/cleanup.sh 2>&1)"; rc=$?
check t9 "exits 0" 0 "$rc"
check t9 "does not call delete-branch" no "$(contains "$(cat "$MOCK_STATE/calls.log")" 'delete-branch')"
check t9 "leaves an unrelated PR uncommented" "" "$(cat "$MOCK_STATE/comment_ops")"

echo "── 10. Cleanup where the amplify delete fails"
setup "amplify-preview/pr-12" "amplify-preview/pr-12" SUCCEED
echo '<!-- amplify-on-demand-preview -->' >"$MOCK_STATE/comment_body.md"
export MOCK_DELETE_BRANCH_FAILS=1
out="$(scripts/amplify-preview/cleanup.sh 2>&1)"; rc=$?
unset MOCK_DELETE_BRANCH_FAILS
check t10 "reports incomplete cleanup" 1 "$rc"
check t10 "still deletes the git branch" yes "$(contains "$(cat "$MOCK_STATE/calls.log")" 'DELETE repos/benstraw/benstrawbridge.com/git/refs/heads/amplify-preview/pr-12')"

echo "── 11. resolve-pr authorisation"
export EVENT_NAME=pull_request_target EVENT_PR_NUMBER=12 REQUEST_ACTOR=benstraw
setup "" "" SUCCEED
export GITHUB_OUTPUT="$MOCK_STATE/out" MOCK_ACTOR_ROLE=admin
out="$(scripts/amplify-preview/resolve-pr.sh 2>&1)"; rc=$?
check t11 "same-repo PR by an admin is allowed" 0 "$rc"
check t11 "exports the API head sha" yes "$(contains "$(cat "$MOCK_STATE/out")" "head_sha=$HEAD_SHA")"
check t11 "exports the pr number" yes "$(contains "$(cat "$MOCK_STATE/out")" "pr_number=12")"

export MOCK_ACTOR_ROLE=read
out="$(scripts/amplify-preview/resolve-pr.sh 2>&1)"; rc=$?
check t11 "read-only user is rejected" 1 "$rc"

export MOCK_ACTOR_ROLE=""
out="$(scripts/amplify-preview/resolve-pr.sh 2>&1)"; rc=$?
check t11 "non-collaborator is rejected" 1 "$rc"

export MOCK_ACTOR_ROLE=admin MOCK_HEAD_REPO=fork/benstrawbridge.com
out="$(scripts/amplify-preview/resolve-pr.sh 2>&1)"; rc=$?
check t11 "fork PR is rejected" 1 "$rc"
check t11 "fork rejection is explained" yes "$(contains "$out" 'comes from a fork')"
unset MOCK_HEAD_REPO

export MOCK_PR_STATE=closed
out="$(scripts/amplify-preview/resolve-pr.sh 2>&1)"; rc=$?
check t11 "closed PR is rejected" 1 "$rc"
unset MOCK_PR_STATE

export EVENT_NAME=workflow_dispatch INPUT_PR_NUMBER='12; rm -rf /'
out="$(scripts/amplify-preview/resolve-pr.sh 2>&1)"; rc=$?
check t11 "non-numeric manual input is rejected" 1 "$rc"

export INPUT_PR_NUMBER=012
out="$(scripts/amplify-preview/resolve-pr.sh 2>&1)"; rc=$?
check t11 "leading-zero manual input is rejected" 1 "$rc"

export INPUT_PR_NUMBER=12 MOCK_ACTOR_ROLE=write GITHUB_OUTPUT="$MOCK_STATE/out2"
out="$(scripts/amplify-preview/resolve-pr.sh 2>&1)"; rc=$?
check t11 "valid manual dispatch is allowed" 0 "$rc"

export MOCK_PR_FILES='.github/workflows/untrusted.yml'
out="$(scripts/amplify-preview/resolve-pr.sh 2>&1)"; rc=$?
check t11 "PRs that change workflow files are rejected" 1 "$rc"
check t11 "workflow-file rejection is explained" yes "$(contains "$out" 'cannot be granted the required Workflows permission')"
unset MOCK_PR_FILES

export MOCK_ACTOR_ROLE=maintain
out="$(scripts/amplify-preview/resolve-pr.sh 2>&1)"; rc=$?
check t11 "maintainer is allowed" 0 "$rc"

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]]
