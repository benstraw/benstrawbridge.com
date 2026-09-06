#!/usr/bin/env bash
# Resolve and authorise a preview deployment request.
#
# Runs before any AWS credential is configured: a request that fails here never
# reaches the deployment job, so fork pull requests and users without write
# access cannot obtain AWS credentials.
#
# Inputs (environment):
#   EVENT_NAME        github.event_name
#   EVENT_PR_NUMBER   github.event.pull_request.number (label events)
#   INPUT_PR_NUMBER   inputs.pr_number (workflow_dispatch)
#   REQUEST_ACTOR     github.actor
#   GITHUB_REPOSITORY owner/repo
#   GH_TOKEN          workflow token
#
# Outputs ($GITHUB_OUTPUT): pr_number, head_sha, short_sha
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/amplify-preview/lib.sh
source "${SCRIPT_DIR}/lib.sh"

require_env EVENT_NAME REQUEST_ACTOR GITHUB_REPOSITORY GH_TOKEN

# The PR number comes from the event payload or from validated manual input;
# a branch or SHA supplied by a user is never trusted.
case "$EVENT_NAME" in
  workflow_dispatch) pr_number="${INPUT_PR_NUMBER:-}" ;;
  *)                 pr_number="${EVENT_PR_NUMBER:-}" ;;
esac

reject() {
  summary "## ❌ Amplify preview request rejected"
  summary ""
  summary "$1"
  die "$1"
}

[[ -n "$pr_number" ]] || reject "No pull request number was supplied."
valid_pr_number "$pr_number" \
  || reject "Pull request number must be digits only (received \`$(printf '%s' "$pr_number" | tr -cd '[:print:]' | head -c 40)\`)."

pr_json="$(gh api "repos/${GITHUB_REPOSITORY}/pulls/${pr_number}")" \
  || reject "Pull request #${pr_number} could not be read from the GitHub API."

state="$(jq -r '.state' <<<"$pr_json")"
head_sha="$(jq -r '.head.sha // empty' <<<"$pr_json")"
head_repo="$(jq -r '.head.repo.full_name // empty' <<<"$pr_json")"
base_repo="$(jq -r '.base.repo.full_name // empty' <<<"$pr_json")"

[[ "$state" == "open" ]] \
  || reject "Pull request #${pr_number} is \`${state}\`. Previews are only deployed for open pull requests."

# Fork pull requests are out of scope: their head commit is untrusted code that
# would otherwise be built by Amplify with the application's environment.
if [[ -z "$head_repo" || "$head_repo" != "$base_repo" ]]; then
  reject "Pull request #${pr_number} comes from a fork (\`${head_repo:-unknown}\`). On-demand previews are limited to branches in \`${base_repo}\`; no AWS credentials were issued."
fi

# The requester must be able to push to this repository. Label events can be
# triggered by anyone with triage access, which is not enough.
perm_json="$(gh api "repos/${GITHUB_REPOSITORY}/collaborators/${REQUEST_ACTOR}/permission" 2>/dev/null)" \
  || reject "\`${REQUEST_ACTOR}\` is not a collaborator on \`${GITHUB_REPOSITORY}\`."
permission="$(jq -r '.permission // empty' <<<"$perm_json")"
role_name="$(jq -r '.role_name // empty' <<<"$perm_json")"
case "${permission}/${role_name}" in
  admin/*|write/*|*/admin|*/maintain|*/write) ;;
  *) reject "\`${REQUEST_ACTOR}\` has \`${role_name:-$permission}\` access; at least write access is required to deploy a preview." ;;
esac

[[ "$head_sha" =~ ^[0-9a-f]{40}$ ]] \
  || reject "The GitHub API returned an unexpected head SHA for pull request #${pr_number}."

{
  echo "pr_number=${pr_number}"
  echo "head_sha=${head_sha}"
  echo "short_sha=${head_sha:0:7}"
} >>"${GITHUB_OUTPUT:-/dev/stdout}"

log "PR #${pr_number} is open, same-repo, head ${head_sha:0:7}, requested by ${REQUEST_ACTOR} (${role_name:-$permission})."
