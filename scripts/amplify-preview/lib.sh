#!/usr/bin/env bash
# Shared helpers for the on-demand Amplify preview workflows.
# Sourced by resolve-pr.sh, deploy.sh and cleanup.sh; not run on its own.

# Hidden marker identifying the single persistent status comment on a PR.
COMMENT_MARKER='<!-- amplify-on-demand-preview -->'

log()  { printf '%s\n' "$*" >&2; }
warn() { printf '::warning::%s\n' "$*" >&2; }
die()  { printf '::error::%s\n' "$*" >&2; exit 1; }

summary() {
  [[ -n "${GITHUB_STEP_SUMMARY:-}" ]] || return 0
  printf '%s\n' "$*" >>"$GITHUB_STEP_SUMMARY"
}

require_env() {
  local name missing=()
  for name in "$@"; do
    [[ -n "${!name:-}" ]] || missing+=("$name")
  done
  (( ${#missing[@]} == 0 )) || die "missing required environment variable(s): ${missing[*]}"
}

# Pull request numbers are digits only. Branch names and API paths are built
# from this value, so nothing downstream runs before it is validated.
valid_pr_number() { [[ "$1" =~ ^[1-9][0-9]{0,8}$ ]]; }

utc_now() { date -u '+%Y-%m-%d %H:%M:%S UTC'; }

# url_encode <string> — percent-encodes a value for use in a URL path segment.
url_encode() { jq -rn --arg s "$1" '$s|@uri'; }

# amplify_console_url <app-id> <branch> [job-id]
amplify_console_url() {
  local url
  url="https://${AWS_REGION}.console.aws.amazon.com/amplify/apps/${1}/branches/$(url_encode "$2")"
  [[ -n "${3:-}" ]] && url="${url}/deployments/${3}"
  printf '%s' "$url"
}

# find_comment_id <pr-number> — prints the id of the marker comment, or nothing.
find_comment_id() {
  gh api --paginate "repos/${GITHUB_REPOSITORY}/issues/${1}/comments" \
    | jq -rs --arg marker "$COMMENT_MARKER" \
        '(add // []) | map(select(.body | contains($marker))) | .[0].id // empty'
}

# upsert_comment <pr-number> <body-file>
# Keeps exactly one status comment per PR: patch it when it exists, create it
# otherwise, so a re-deploy never adds a second comment.
upsert_comment() {
  local pr="$1" body_file="$2" id
  id="$(find_comment_id "$pr")" || return 1
  if [[ -n "$id" ]]; then
    jq -n --rawfile body "$body_file" '{body: $body}' \
      | gh api --method PATCH "repos/${GITHUB_REPOSITORY}/issues/comments/${id}" --input - >/dev/null
  else
    jq -n --rawfile body "$body_file" '{body: $body}' \
      | gh api --method POST "repos/${GITHUB_REPOSITORY}/issues/${pr}/comments" --input - >/dev/null
  fi
}

# render_comment <status> <detail> <outfile>
# One comment format shared by the deploy and cleanup workflows. Values are read
# from the caller's environment: PREVIEW_URL, SHORT_SHA, JOB_ID, RUN_URL,
# AMPLIFY_APP_ID, AMPLIFY_BRANCH.
render_comment() {
  local status="$1" detail="${2:-}" out="$3" heading
  case "$status" in
    deploying) heading='⏳ **Deploying** — Amplify is building this pull request.' ;;
    ready)     heading='✅ **Ready** — the on-demand preview is live.' ;;
    failed)    heading='❌ **Failed** — the on-demand preview did not deploy.' ;;
    removed)   heading='🧹 **Removed** — the on-demand preview has been deleted.' ;;
    *) die "unknown comment status: ${status}" ;;
  esac

  {
    printf '%s\n\n' "$COMMENT_MARKER"
    printf '### Amplify preview\n\n%s\n\n' "$heading"
    printf '| | |\n| --- | --- |\n'
    if [[ "$status" == "ready" && -n "${PREVIEW_URL:-}" ]]; then
      printf '| **Preview URL** | %s |\n' "$PREVIEW_URL"
    elif [[ "$status" == "deploying" && -n "${PREVIEW_URL:-}" ]]; then
      printf '| **Preview URL** | `%s` (live once the build succeeds) |\n' "$PREVIEW_URL"
    fi
    if [[ -n "${SHORT_SHA:-}" ]]; then
      printf '| **Commit** | `%s` |\n' "$SHORT_SHA"
    fi
    if [[ -n "${JOB_ID:-}" && -n "${AMPLIFY_APP_ID:-}" && -n "${AMPLIFY_BRANCH:-}" ]]; then
      printf '| **Amplify job** | [#%s](%s) |\n' \
        "$JOB_ID" "$(amplify_console_url "$AMPLIFY_APP_ID" "$AMPLIFY_BRANCH" "$JOB_ID")"
    fi
    if [[ -n "${RUN_URL:-}" ]]; then
      printf '| **Workflow run** | [logs](%s) |\n' "$RUN_URL"
    fi
    printf '| **Updated** | %s |\n' "$(utc_now)"
    if [[ -n "$detail" ]]; then
      printf '\n%s\n' "$detail"
    fi
    if [[ "$status" != "removed" ]]; then
      printf '\n<sub>Previews are built on request only. A new commit is **not** deployed by itself — re-request it with the `deploy-preview` label or the *Amplify preview (on demand)* workflow.</sub>\n'
    fi
  } >"$out"
}
