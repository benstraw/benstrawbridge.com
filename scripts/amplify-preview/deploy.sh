#!/usr/bin/env bash
# Deploy one pull request to an isolated, on-demand AWS Amplify preview.
#
# Every input arrives through the environment, so the script can be run by hand
# with the same AWS and gh credentials the workflow uses.
#
# Inputs (environment):
#   PR_NUMBER, HEAD_SHA        resolved and authorised by resolve-pr.sh
#   AMPLIFY_APP_ID, AWS_REGION repository variables
#   GITHUB_REPOSITORY, GH_TOKEN, RUN_URL
# Optional:
#   ENV_POLICY_FILE            default .github/amplify-preview-env.json
#   DEPLOY_TIMEOUT_SECONDS     default 1800
#   POLL_INTERVAL_SECONDS      default 15
#   PROBE_PREVIEW_URL          default true
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/amplify-preview/lib.sh
source "${SCRIPT_DIR}/lib.sh"

require_env PR_NUMBER HEAD_SHA AMPLIFY_APP_ID AWS_REGION GITHUB_REPOSITORY GH_TOKEN
: "${ENV_POLICY_FILE:=.github/amplify-preview-env.json}"
: "${DEPLOY_TIMEOUT_SECONDS:=1800}"
: "${POLL_INTERVAL_SECONDS:=15}"
: "${PROBE_PREVIEW_URL:=true}"
: "${RUN_URL:=}"

valid_pr_number "$PR_NUMBER" || die "PR_NUMBER must be digits only"
[[ "$HEAD_SHA" =~ ^[0-9a-f]{40}$ ]] || die "HEAD_SHA must be a 40-character commit SHA"

# Identity of the preview. The Amplify branch tracks a real Git branch, so both
# carry the same name; displayName gives the URL its "pr-N" prefix.
readonly GIT_BRANCH="amplify-preview/pr-${PR_NUMBER}"
readonly AMPLIFY_BRANCH="$GIT_BRANCH"
readonly URL_PREFIX="pr-${PR_NUMBER}"
SHORT_SHA="${HEAD_SHA:0:7}"
JOB_ID=""
PREVIEW_URL=""
STATUS_DETAIL=""
export AWS_REGION

WORKDIR="$(mktemp -d)"
trap 'on_exit' EXIT

on_exit() {
  local code=$?
  trap - EXIT
  if (( code != 0 )); then
    render_comment failed "${STATUS_DETAIL:-The workflow run did not complete. See the run logs for details.}" \
      "${WORKDIR}/comment.md" 2>/dev/null || true
    upsert_comment "$PR_NUMBER" "${WORKDIR}/comment.md" 2>/dev/null || warn "could not update the pull request comment"
    summary_failure "${STATUS_DETAIL:-The workflow run did not complete.}"
  fi
  rm -rf "$WORKDIR"
  exit "$code"
}

# fail <message> — record the reason so the PR comment and job summary explain
# the failure, then abort.
fail() { STATUS_DETAIL="$1"; die "$1"; }

summary_failure() {
  summary "## ❌ Amplify preview failed — PR #${PR_NUMBER}"
  summary ""
  summary "$1"
  summary ""
  summary "Preview resources are left in place for diagnosis. To remove them by hand:"
  summary ""
  summary '```bash'
  summary "aws amplify delete-branch --app-id ${AMPLIFY_APP_ID} --branch-name '${AMPLIFY_BRANCH}' --region ${AWS_REGION}"
  summary "gh api --method DELETE repos/${GITHUB_REPOSITORY}/git/refs/heads/${GIT_BRANCH}"
  summary '```'
  summary ""
  summary "Or re-run the *Amplify preview cleanup* workflow for PR #${PR_NUMBER}."
}

# ---------------------------------------------------------------------------
# 1. Inspect the existing application
# ---------------------------------------------------------------------------
log "Reading Amplify app ${AMPLIFY_APP_ID} in ${AWS_REGION}"
app_json="$(aws amplify get-app --app-id "$AMPLIFY_APP_ID" --output json)" \
  || fail "Could not read Amplify app \`${AMPLIFY_APP_ID}\`. Check \`AMPLIFY_APP_ID\`, \`AWS_REGION\` and the IAM role's \`amplify:GetApp\` permission."

DEFAULT_DOMAIN="$(jq -r '.app.defaultDomain // empty'            <<<"$app_json")"
PROD_BRANCH="$(jq -r    '.app.productionBranch.branchName // empty' <<<"$app_json")"
APP_REPOSITORY="$(jq -r '.app.repository // empty'               <<<"$app_json")"
APP_PLATFORM="$(jq -r   '.app.platform // empty'                 <<<"$app_json")"
AUTO_BRANCH_CREATION="$(jq -r '.app.enableAutoBranchCreation // false' <<<"$app_json")"

[[ -n "$DEFAULT_DOMAIN" ]] || fail "The Amplify app did not return a \`defaultDomain\`; the preview URL cannot be constructed."
PREVIEW_URL="https://${URL_PREFIX}.${DEFAULT_DOMAIN}"

# ---------------------------------------------------------------------------
# 2. Production safeguards
# ---------------------------------------------------------------------------
# The Amplify app must be the one connected to this repository.
if [[ -n "$APP_REPOSITORY" ]]; then
  normalised="${APP_REPOSITORY%.git}"
  normalised="${normalised%/}"
  shopt -s nocasematch
  if [[ "$normalised" != *"/${GITHUB_REPOSITORY}" ]]; then
    shopt -u nocasematch
    fail "Amplify app \`${AMPLIFY_APP_ID}\` is connected to \`${APP_REPOSITORY}\`, not to \`${GITHUB_REPOSITORY}\`. Refusing to deploy."
  fi
  shopt -u nocasematch
fi

# Never touch the production branch, whatever the PR number is.
if [[ -n "$PROD_BRANCH" && "$AMPLIFY_BRANCH" == "$PROD_BRANCH" ]]; then
  fail "The preview branch name collides with the production branch \`${PROD_BRANCH}\`. Refusing to deploy."
fi

# Automatic branch creation would turn the temporary Git branch into an
# uncontrolled Amplify branch, which is exactly what on-demand previews avoid.
if [[ "$AUTO_BRANCH_CREATION" == "true" ]]; then
  matched=""
  while IFS= read -r pattern; do
    [[ -n "$pattern" ]] || continue
    # shellcheck disable=SC2053 # intentional glob match against the app's pattern
    if [[ "$GIT_BRANCH" == $pattern ]]; then matched="$pattern"; fi
  done < <(jq -r '.app.autoBranchCreationPatterns // [] | .[]' <<<"$app_json")
  if [[ -n "$matched" ]]; then
    fail "The app has branch auto-detection enabled and pattern \`${matched}\` matches \`${GIT_BRANCH}\`. Disable auto-detection or narrow the pattern before using on-demand previews."
  fi
  warn "The app has branch auto-detection enabled; no pattern matches ${GIT_BRANCH}, continuing."
fi

if [[ -n "$APP_PLATFORM" && "$APP_PLATFORM" != "WEB" ]]; then
  warn "App platform is ${APP_PLATFORM}; previews of non-static apps may need branch-level compute settings."
fi

# ---------------------------------------------------------------------------
# 3. Environment-variable audit
# ---------------------------------------------------------------------------
# An Amplify branch inherits the app's environment variables. Every app-level
# variable must be classified in ENV_POLICY_FILE before it can reach a preview
# build, so a production-only value is never exposed by accident.
[[ -f "$ENV_POLICY_FILE" ]] || fail "Environment policy file \`${ENV_POLICY_FILE}\` is missing."
jq -e 'type == "object"' "$ENV_POLICY_FILE" >/dev/null \
  || fail "Environment policy file \`${ENV_POLICY_FILE}\` is not a JSON object."

unclassified="$(jq -r --slurpfile policy "$ENV_POLICY_FILE" '
    ($policy[0].inherit // [])            as $inherit
  | (($policy[0].override // {}) | keys)  as $override
  | ((.app.environmentVariables // {} | keys) - $inherit - $override)
  | .[]' <<<"$app_json")"

if [[ -n "$unclassified" ]]; then
  names="$(printf '%s' "$unclassified" | tr '\n' ',' | sed 's/,/, /g; s/, $//')"
  fail "$(printf 'Unaudited Amplify environment variables: `%s`.\n\nEach app-level variable must be listed in `%s` — under `inherit` if it is safe for a preview build, or under `override` with a preview-safe value. No preview was deployed.' "$names" "$ENV_POLICY_FILE")"
fi

override_json="$(jq -c '.override // {}' "$ENV_POLICY_FILE")"
inherited_names="$(jq -r '(.app.environmentVariables // {} | keys) | join(", ")' <<<"$app_json")"
log "Audited app environment variables: ${inherited_names:-none}"

# ---------------------------------------------------------------------------
# 4. Point the temporary Git branch at the PR head commit
# ---------------------------------------------------------------------------
log "Setting ${GIT_BRANCH} to ${HEAD_SHA}"
if gh api "repos/${GITHUB_REPOSITORY}/git/ref/heads/${GIT_BRANCH}" >/dev/null 2>&1; then
  jq -n --arg sha "$HEAD_SHA" '{sha: $sha, force: true}' \
    | gh api --method PATCH "repos/${GITHUB_REPOSITORY}/git/refs/heads/${GIT_BRANCH}" --input - >/dev/null \
    || fail "Could not fast-forward \`${GIT_BRANCH}\` to \`${SHORT_SHA}\`."
else
  jq -n --arg ref "refs/heads/${GIT_BRANCH}" --arg sha "$HEAD_SHA" '{ref: $ref, sha: $sha}' \
    | gh api --method POST "repos/${GITHUB_REPOSITORY}/git/refs" --input - >/dev/null \
    || fail "Could not create \`${GIT_BRANCH}\` at \`${SHORT_SHA}\`."
fi

pushed_sha="$(gh api "repos/${GITHUB_REPOSITORY}/git/ref/heads/${GIT_BRANCH}" --jq '.object.sha')" \
  || fail "Could not read \`${GIT_BRANCH}\` back after updating it."
[[ "$pushed_sha" == "$HEAD_SHA" ]] \
  || fail "\`${GIT_BRANCH}\` points at \`${pushed_sha:0:7}\` instead of the requested \`${SHORT_SHA}\`."

# ---------------------------------------------------------------------------
# 5-6. Create or converge the Amplify branch
# ---------------------------------------------------------------------------
branch_args=(
  --app-id "$AMPLIFY_APP_ID"
  --branch-name "$AMPLIFY_BRANCH"
  --stage PULL_REQUEST
  --no-enable-auto-build
  --no-enable-pull-request-preview
  --display-name "$URL_PREFIX"
  --description "On-demand preview for ${GITHUB_REPOSITORY}#${PR_NUMBER}"
  --environment-variables "$override_json"
)

# Match the framework the application already uses rather than guessing.
if [[ -n "$PROD_BRANCH" ]]; then
  prod_json="$(aws amplify get-branch --app-id "$AMPLIFY_APP_ID" --branch-name "$PROD_BRANCH" --output json 2>/dev/null || true)"
  if [[ -n "$prod_json" ]]; then
    prod_framework="$(jq -r '.branch.framework // empty' <<<"$prod_json")"
    if [[ -n "$prod_framework" ]]; then
      branch_args+=(--framework "$prod_framework")
    fi
    if [[ -n "$(jq -r '.branch.buildSpec // empty' <<<"$prod_json")" ]]; then
      warn "Production branch ${PROD_BRANCH} carries a branch-level build spec. The preview uses the app/repository build spec instead; add an explicit override if the preview needs it."
    fi
  else
    warn "Could not read production branch ${PROD_BRANCH}; creating the preview branch without a framework hint."
  fi
fi

if aws amplify get-branch --app-id "$AMPLIFY_APP_ID" --branch-name "$AMPLIFY_BRANCH" >/dev/null 2>&1; then
  log "Amplify branch ${AMPLIFY_BRANCH} exists; converging its settings"
  aws amplify update-branch "${branch_args[@]}" >/dev/null \
    || fail "Could not update Amplify branch \`${AMPLIFY_BRANCH}\`."
else
  log "Creating Amplify branch ${AMPLIFY_BRANCH}"
  aws amplify create-branch "${branch_args[@]}" >/dev/null \
    || fail "Could not create Amplify branch \`${AMPLIFY_BRANCH}\`."
fi

# ---------------------------------------------------------------------------
# 7. Start one explicit RELEASE job
# ---------------------------------------------------------------------------
JOB_ID="$(aws amplify start-job \
  --app-id "$AMPLIFY_APP_ID" \
  --branch-name "$AMPLIFY_BRANCH" \
  --job-type RELEASE \
  --job-reason "On-demand preview for ${GITHUB_REPOSITORY}#${PR_NUMBER} at ${SHORT_SHA}" \
  --query 'jobSummary.jobId' --output text)" \
  || fail "Could not start an Amplify RELEASE job for \`${AMPLIFY_BRANCH}\`."
[[ -n "$JOB_ID" && "$JOB_ID" != "None" ]] || fail "Amplify did not return a job id for \`${AMPLIFY_BRANCH}\`."
log "Started Amplify job ${JOB_ID}"

render_comment deploying "" "${WORKDIR}/comment.md"
upsert_comment "$PR_NUMBER" "${WORKDIR}/comment.md" || warn "could not post the pull request comment"

# ---------------------------------------------------------------------------
# 8. Poll that job to a terminal state
# ---------------------------------------------------------------------------
deadline=$(( $(date +%s) + DEPLOY_TIMEOUT_SECONDS ))
errors=0
status="UNKNOWN"
built_commit=""
while :; do
  if job_json="$(aws amplify get-job --app-id "$AMPLIFY_APP_ID" --branch-name "$AMPLIFY_BRANCH" --job-id "$JOB_ID" --output json 2>/dev/null)"; then
    errors=0
    status="$(jq -r '.job.summary.status // "UNKNOWN"' <<<"$job_json")"
    built_commit="$(jq -r '.job.summary.commitId // empty' <<<"$job_json")"
  else
    errors=$(( errors + 1 ))
    (( errors < 5 )) || fail "\`aws amplify get-job\` failed ${errors} times in a row while polling job ${JOB_ID}."
    warn "get-job failed (${errors}/5); retrying"
  fi

  case "$status" in
    SUCCEED) log "Job ${JOB_ID} succeeded"; break ;;
    FAILED)    fail "Amplify job [#${JOB_ID}]($(amplify_console_url "$AMPLIFY_APP_ID" "$AMPLIFY_BRANCH" "$JOB_ID")) failed. The preview branch was kept for diagnosis." ;;
    CANCELLED) fail "Amplify job [#${JOB_ID}]($(amplify_console_url "$AMPLIFY_APP_ID" "$AMPLIFY_BRANCH" "$JOB_ID")) was cancelled." ;;
  esac

  if (( $(date +%s) >= deadline )); then
    fail "Amplify job [#${JOB_ID}]($(amplify_console_url "$AMPLIFY_APP_ID" "$AMPLIFY_BRANCH" "$JOB_ID")) did not finish within ${DEPLOY_TIMEOUT_SECONDS}s (last status \`${status}\`)."
  fi
  log "job ${JOB_ID}: ${status}"
  sleep "$POLL_INTERVAL_SECONDS"
done

if [[ -n "$built_commit" && "$built_commit" != "$HEAD_SHA" ]]; then
  warn "Amplify built commit ${built_commit:0:7}, not the requested ${SHORT_SHA}. Re-request the preview if the branch moved."
fi

# ---------------------------------------------------------------------------
# 9. Confirm the preview URL actually serves
# ---------------------------------------------------------------------------
# displayName is documented as the default domain prefix, but the URL is worth
# confirming before it is published to the pull request.
probe() {
  local code
  code="$(curl -sS -o /dev/null -w '%{http_code}' --max-time 20 "$1" 2>/dev/null || true)"
  printf '%s' "${code:-000}"
}

url_note=""
if [[ "$PROBE_PREVIEW_URL" == "true" ]]; then
  fallback_url="https://$(printf '%s' "$AMPLIFY_BRANCH" | tr '/_.' '-').${DEFAULT_DOMAIN}"
  reachable=""
  for attempt in 1 2 3 4 5 6; do
    code="$(probe "$PREVIEW_URL")"
    if [[ "$code" =~ ^[123] ]]; then reachable="$PREVIEW_URL"; break; fi
    log "preview URL not serving yet (HTTP ${code}, attempt ${attempt}/6)"
    sleep 5
  done
  if [[ -z "$reachable" && "$fallback_url" != "$PREVIEW_URL" ]]; then
    code="$(probe "$fallback_url")"
    if [[ "$code" =~ ^[123] ]]; then
      warn "Preview served from ${fallback_url}; the displayName prefix did not take effect."
      PREVIEW_URL="$fallback_url"
      reachable="$fallback_url"
    fi
  fi
  if [[ -z "$reachable" ]]; then
    url_note="> The Amplify job succeeded but the preview URL did not answer yet. It is usually a short propagation delay; reload in a minute."
    warn "preview URL did not answer after the build succeeded"
  fi
fi

# ---------------------------------------------------------------------------
# 10-11. Report to the pull request and to the job summary
# ---------------------------------------------------------------------------
if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  {
    echo "preview_url=${PREVIEW_URL}"
    echo "amplify_job_id=${JOB_ID}"
  } >>"$GITHUB_OUTPUT"
fi

render_comment ready "$url_note" "${WORKDIR}/comment.md"
upsert_comment "$PR_NUMBER" "${WORKDIR}/comment.md" || warn "could not update the pull request comment"

summary "## ✅ Amplify preview ready — PR #${PR_NUMBER}"
summary ""
summary "| | |"
summary "| --- | --- |"
summary "| Preview URL | ${PREVIEW_URL} |"
summary "| Commit | \`${SHORT_SHA}\` |"
summary "| Amplify branch | \`${AMPLIFY_BRANCH}\` (stage \`PULL_REQUEST\`, auto-build off) |"
summary "| Git branch | \`${GIT_BRANCH}\` |"
summary "| Amplify job | [#${JOB_ID}]($(amplify_console_url "$AMPLIFY_APP_ID" "$AMPLIFY_BRANCH" "$JOB_ID")) |"
summary "| Inherited app variables | ${inherited_names:-none} |"
summary "| Deployed (UTC) | $(utc_now) |"
summary ""
summary "Remove this preview by closing the pull request, by running the *Amplify preview cleanup* workflow, or by hand:"
summary ""
summary '```bash'
summary "aws amplify delete-branch --app-id ${AMPLIFY_APP_ID} --branch-name '${AMPLIFY_BRANCH}' --region ${AWS_REGION}"
summary "gh api --method DELETE repos/${GITHUB_REPOSITORY}/git/refs/heads/${GIT_BRANCH}"
summary '```'
