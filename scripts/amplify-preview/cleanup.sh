#!/usr/bin/env bash
# Remove the on-demand Amplify preview for a pull request.
#
# Idempotent by design: a missing Amplify branch or Git branch is success, and a
# failure removing one resource never stops the attempt on the other.
#
# Inputs (environment):
#   PR_NUMBER, AMPLIFY_APP_ID, AWS_REGION, GITHUB_REPOSITORY, GH_TOKEN, RUN_URL
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/amplify-preview/lib.sh
source "${SCRIPT_DIR}/lib.sh"

require_env PR_NUMBER AMPLIFY_APP_ID AWS_REGION GITHUB_REPOSITORY GH_TOKEN
: "${RUN_URL:=}"

valid_pr_number "$PR_NUMBER" || die "PR_NUMBER must be digits only"

readonly GIT_BRANCH="amplify-preview/pr-${PR_NUMBER}"
readonly AMPLIFY_BRANCH="$GIT_BRANCH"
export AWS_REGION

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

declare -a failures=()
amplify_result="not found"
git_result="not found"

# Never delete a branch that is not a preview branch, whatever is passed in.
[[ "$AMPLIFY_BRANCH" == amplify-preview/pr-* ]] || die "refusing to delete non-preview branch ${AMPLIFY_BRANCH}"

prod_branch="$(aws amplify get-app --app-id "$AMPLIFY_APP_ID" --query 'app.productionBranch.branchName' --output text 2>/dev/null || true)"
if [[ -n "$prod_branch" && "$prod_branch" != "None" && "$prod_branch" == "$AMPLIFY_BRANCH" ]]; then
  die "refusing to delete the production branch ${prod_branch}"
fi

# --- Amplify branch -------------------------------------------------------
if aws amplify get-branch --app-id "$AMPLIFY_APP_ID" --branch-name "$AMPLIFY_BRANCH" >/dev/null 2>&1; then
  if aws amplify delete-branch --app-id "$AMPLIFY_APP_ID" --branch-name "$AMPLIFY_BRANCH" >/dev/null 2>"${WORKDIR}/amplify.err"; then
    amplify_result="deleted"
    log "Deleted Amplify branch ${AMPLIFY_BRANCH}"
  else
    amplify_result="**failed**"
    failures+=("Amplify branch \`${AMPLIFY_BRANCH}\`: $(tail -n 1 "${WORKDIR}/amplify.err" | tr -d '\r')")
    warn "could not delete Amplify branch ${AMPLIFY_BRANCH}"
  fi
else
  log "Amplify branch ${AMPLIFY_BRANCH} is already absent"
fi

# --- Git branch -----------------------------------------------------------
if gh api "repos/${GITHUB_REPOSITORY}/git/ref/heads/${GIT_BRANCH}" >/dev/null 2>&1; then
  if gh api --method DELETE "repos/${GITHUB_REPOSITORY}/git/refs/heads/${GIT_BRANCH}" >/dev/null 2>"${WORKDIR}/git.err"; then
    git_result="deleted"
    log "Deleted Git branch ${GIT_BRANCH}"
  else
    git_result="**failed**"
    failures+=("Git branch \`${GIT_BRANCH}\`: $(tail -n 1 "${WORKDIR}/git.err" | tr -d '\r')")
    warn "could not delete Git branch ${GIT_BRANCH}"
  fi
else
  log "Git branch ${GIT_BRANCH} is already absent"
fi

# --- Report ---------------------------------------------------------------
# Only touch the pull request when a preview was actually announced there.
if [[ -n "$(find_comment_id "$PR_NUMBER" || true)" ]]; then
  if (( ${#failures[@]} == 0 )); then
    detail="The temporary Amplify branch and Git branch have been deleted."
  else
    detail="Cleanup was incomplete:"$'\n\n'
    for failure in "${failures[@]}"; do detail+="- ${failure}"$'\n'; done
  fi
  render_comment removed "$detail" "${WORKDIR}/comment.md"
  upsert_comment "$PR_NUMBER" "${WORKDIR}/comment.md" || warn "could not update the pull request comment"
fi

if (( ${#failures[@]} == 0 )); then
  summary "## 🧹 Amplify preview cleaned up — PR #${PR_NUMBER}"
else
  summary "## ⚠️ Amplify preview cleanup incomplete — PR #${PR_NUMBER}"
fi
summary ""
summary "| Resource | Result |"
summary "| --- | --- |"
summary "| Amplify branch \`${AMPLIFY_BRANCH}\` | ${amplify_result} |"
summary "| Git branch \`${GIT_BRANCH}\` | ${git_result} |"

if (( ${#failures[@]} > 0 )); then
  summary ""
  summary "Remaining work:"
  summary ""
  for failure in "${failures[@]}"; do summary "- ${failure}"; done
  summary ""
  summary '```bash'
  summary "aws amplify delete-branch --app-id ${AMPLIFY_APP_ID} --branch-name '${AMPLIFY_BRANCH}' --region ${AWS_REGION}"
  summary "gh api --method DELETE repos/${GITHUB_REPOSITORY}/git/refs/heads/${GIT_BRANCH}"
  summary '```'
  die "cleanup incomplete: ${#failures[@]} resource(s) could not be removed"
fi
