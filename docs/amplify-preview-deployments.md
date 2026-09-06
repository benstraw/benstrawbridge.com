# On-demand Amplify preview deployments

Preview builds for this site are **requested, never automatic**. Opening a pull
request, pushing to it, or reopening it deploys nothing. A preview appears only
when someone adds the `deploy-preview` label or runs the workflow by hand, and it
disappears when the pull request closes.

This exists because Amplify's own *Pull request previews* setting builds every
pull request as soon as it is opened. That setting stays **off**; nothing here
touches the production branch, the custom domain, DNS, redirects, environment
variables, the backend, or `amplify.yml`.

| File | Role |
| --- | --- |
| `.github/workflows/amplify-preview.yml` | Requested deployment (label or manual dispatch) |
| `.github/workflows/amplify-preview-cleanup.yml` | Removal on pull-request close |
| `.github/amplify-preview-env.json` | Audit of the app environment variables a preview may inherit |
| `scripts/amplify-preview/resolve-pr.sh` | Resolves and authorises the request, before any AWS credential exists |
| `scripts/amplify-preview/deploy.sh` | Amplify branch, RELEASE job, polling, status reporting |
| `scripts/amplify-preview/cleanup.sh` | Idempotent removal of both branches |
| `scripts/amplify-preview/lib.sh` | Shared helpers (status comment, summaries) |
| `scripts/amplify-preview/tests/` | Mock-based tests — `npm run test:amplify-preview` |

## Preview identity and URL

For pull request **N**:

| | |
| --- | --- |
| Temporary Git branch | `amplify-preview/pr-N` |
| Amplify branch | `amplify-preview/pr-N` |
| Amplify branch `displayName` | `pr-N` |
| Amplify stage | `PULL_REQUEST` |
| Automatic builds | disabled |
| Preview URL | `https://pr-N.<app default domain>` — for example `https://pr-12.d123abcxyz.amplifyapp.com` |

The URL is built from the `defaultDomain` the Amplify API returns for the app, never
from a hard-coded domain.

### Why the Amplify branch is not literally named `pr-N`

An Amplify branch **is** a repository branch: a `RELEASE` job builds "the latest
change from the specified branch", so an Amplify branch named `pr-12` would look
for a Git branch named `pr-12`. Since the temporary Git branch is
`amplify-preview/pr-12`, the Amplify branch carries that same name, and
`displayName` — documented as "the display name for a branch, used as the default
domain prefix" — supplies the `pr-12` URL prefix.

So the *URL* is exactly `pr-N` as specified; only the internal Amplify branch
identifier differs, and it matches the Git branch it tracks. As a safety net the
deploy script probes the resulting URL after a successful build and falls back to
the sanitised branch name (`https://amplify-preview-pr-12.<domain>`) if
`displayName` did not take effect, reporting whichever actually serves.

## One-time setup

### 1. AWS: OIDC provider

If the account has no GitHub OIDC provider yet, create one for
`https://token.actions.githubusercontent.com` with audience `sts.amazonaws.com`.

### 2. AWS: IAM role

Create a dedicated role — for example `github-amplify-preview`. Nothing else uses
it, and no AWS access key is ever created for it.

**Trust policy** (replace `<ACCOUNT_ID>`; the repository is already filled in):

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::<ACCOUNT_ID>:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
          "token.actions.githubusercontent.com:sub": "repo:benstraw/benstrawbridge.com:environment:amplify-preview"
        }
      }
    }
  ]
}
```

The `sub` condition pins the role to this repository **and** to the
`amplify-preview` GitHub environment. Both jobs that touch AWS declare that
environment, so no other workflow, branch, or repository can assume the role.

**Permissions policy** (replace `<ACCOUNT_ID>`, `<REGION>`, `<APP_ID>`,
`<PRODUCTION_BRANCH>`):

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "InspectTheApp",
      "Effect": "Allow",
      "Action": "amplify:GetApp",
      "Resource": "arn:aws:amplify:<REGION>:<ACCOUNT_ID>:apps/<APP_ID>"
    },
    {
      "Sid": "ReadProductionBranchConfiguration",
      "Effect": "Allow",
      "Action": "amplify:GetBranch",
      "Resource": "arn:aws:amplify:<REGION>:<ACCOUNT_ID>:apps/<APP_ID>/branches/<PRODUCTION_BRANCH>"
    },
    {
      "Sid": "ManagePreviewBranchesOnly",
      "Effect": "Allow",
      "Action": [
        "amplify:GetBranch",
        "amplify:CreateBranch",
        "amplify:UpdateBranch",
        "amplify:DeleteBranch"
      ],
      "Resource": "arn:aws:amplify:<REGION>:<ACCOUNT_ID>:apps/<APP_ID>/branches/amplify-preview/pr-*"
    },
    {
      "Sid": "RunPreviewJobs",
      "Effect": "Allow",
      "Action": ["amplify:StartJob", "amplify:GetJob"],
      "Resource": "arn:aws:amplify:<REGION>:<ACCOUNT_ID>:apps/<APP_ID>/branches/amplify-preview/pr-*/jobs/*"
    }
  ]
}
```

Write access is restricted to branches under `amplify-preview/pr-`. The role
**cannot** update or delete the production branch, change app settings, touch
domains, or start a job on any branch other than a preview — that limit is enforced
by IAM, not only by the scripts.

### 3. GitHub: environment

Create an environment named `amplify-preview` (Settings → Environments). It exists
so the OIDC subject claim can be pinned; it needs no secrets.

Adding **required reviewers** gives manual approval before each preview build — but
the cleanup workflow uses the same environment, so cleanup would then wait for an
approval too. Leave reviewers off unless that is acceptable.

### 4. GitHub: repository variables

Settings → Secrets and variables → Actions → **Variables** (not secrets):

| Variable | Example | Meaning |
| --- | --- | --- |
| `AWS_REGION` | `us-west-2` | Region of the existing Amplify app |
| `AMPLIFY_APP_ID` | `d123abcxyz` | Existing Amplify app id |
| `AWS_PREVIEW_ROLE_ARN` | `arn:aws:iam::<ACCOUNT_ID>:role/github-amplify-preview` | Role created above |

No AWS access-key id or secret access key is stored anywhere.

### 5. GitHub: label

Create a label named exactly `deploy-preview`.

### 6. Merge to the default branch

`pull_request_target` and `workflow_dispatch` both read the workflow from the
**default branch**. Until these files are on `main`, adding the label does nothing
and the workflow does not appear in the Actions tab. This is the one setup step
that cannot be tested from a feature branch.

### 7. Classify the inherited environment variables

The first run reads the app's environment variables and stops if any of them is
unclassified — see [Environment variables](#environment-variables-the-audit-gate).

## Using a preview

**Request one** — add the `deploy-preview` label to an open pull request, or run
*Actions → Amplify preview (on demand) → Run workflow* and enter the pull request
number.

**Refresh after new commits** — pushing does **not** rebuild. Either remove and
re-add the `deploy-preview` label, or run the workflow manually. The label is
deliberately left in place after a deployment, so it is a visible marker that the
pull request has a preview rather than a one-shot button.

**Inspect** — the workflow keeps one comment on the pull request (identified by the
hidden marker `<!-- amplify-on-demand-preview -->`) showing status, preview URL,
deployed short SHA, the Amplify job link and the workflow run link. The same
information goes to the job summary. Re-deploying edits that comment; it never adds
another.

**Remove** — close the pull request. Cleanup also runs on demand from *Actions →
Amplify preview cleanup*, and is safe to run when nothing is left to delete.

## What a deployment does

1. Resolves the pull request through the GitHub API and confirms it is open.
2. Confirms the requester has at least write access (a label can otherwise be added
   with triage access).
3. Reads the head SHA **from the API** — a branch or SHA typed into the manual
   input is never trusted; the input is a pull-request number and must be digits.
4. Creates or force-updates `amplify-preview/pr-N` to exactly that SHA, then reads
   the ref back to confirm it landed.
5. Reads the Amplify app: default domain, production branch, connected repository,
   platform, branch auto-detection, environment variables.
6. Creates the Amplify branch when absent — auto-build off, stage `PULL_REQUEST`,
   native PR previews off, framework copied from the production branch — or
   converges those same settings when it already exists.
7. Starts one explicit `RELEASE` job and polls that job id until it reaches
   `SUCCEED`, `FAILED` or `CANCELLED`, or until the 30-minute timeout.
8. Publishes the result to the pull request comment and the job summary.

The workflow fails when the Amplify job fails, is cancelled, or times out.

## Security model

**Fork pull requests are refused.** A preview builds the head commit with the
application's build environment, so only branches in this repository are eligible.
The authorisation job runs *before* any AWS credential is configured and holds only
read permissions, so a fork request cannot obtain credentials — it fails with an
explanation in the job summary.

**The pull request head is never checked out.** Both workflows use
`pull_request_target`, which runs in the base-repository context with a writable
token. That is safe here only because no step checks out or executes pull-request
code: the temporary branch is created through the GitHub refs API, and the scripts
and the environment-variable policy always come from the base branch. Do not add a
step that checks out `github.event.pull_request.head.sha`, and do not add a build,
install, or lint step to these workflows.

**Least-privilege AWS access** — see the permissions policy above.

**Previews are public.** `https://pr-N.<default domain>` is reachable by anyone who
knows it. For a public marketing site that is usually fine; if a particular preview
must not be, set basic auth on the branch in the Amplify console after it is
created (`aws amplify update-branch --enable-basic-auth --basic-auth-credentials ...`).

### Environment variables: the audit gate

An Amplify branch inherits the **app-level** environment variables. Branch-level
variables on the production branch are *not* copied to previews.

`.github/amplify-preview-env.json` records the decision for every app-level
variable:

```json
{
  "inherit": ["_LIVE_UPDATES"],
  "override": {}
}
```

* `inherit` — safe for a preview build; passes through unchanged.
* `override` — replaced with a preview-safe value at branch level. **Never put a
  secret here**; the file is public. Use it for values that should differ in a
  preview (an analytics key, a feature flag).

A variable that appears in neither list stops the deployment **before** any branch
is created or any credential reaches a build, and the failure names it. That is
deliberate: it forces the audit to happen against the app's real configuration
rather than an assumption. `_LIVE_UPDATES` is pre-classified because Amplify writes
it itself to pin build-tool versions (it is a package/version list, not a secret) —
confirm its value before the first run and remove it from `inherit` if it holds
anything else.

To see the current list without deploying:

```bash
aws amplify get-app --app-id "$AMPLIFY_APP_ID" --region "$AWS_REGION" \
  --query 'app.environmentVariables' --output json | jq 'keys'
```

If a production-only secret turns up that a preview build genuinely needs, stop:
either give the preview a non-production value through `override`, or do not deploy
previews of that build.

## Concurrency

Both workflows use the group `amplify-preview-pr-<N>` with
`cancel-in-progress: true`. Sharing one group is intentional: a close event is
always the newest run in the group, so it supersedes and cancels a deployment still
in flight for that pull request, and no older deployment run can cancel a cleanup.
Two pull requests never contend, because the group is per pull request.

## Failure and recovery

* A failure **before** the Amplify branch exists leaves nothing behind, and
  production is untouched.
* A failure **after** resources exist keeps them for diagnosis. The job summary
  prints the exact commands to remove them.
* Re-running a deployment recovers an existing preview: the branch settings are
  converged and the same URL is redeployed. Manual deletion is never required.
* Cleanup treats a missing Amplify branch or Git branch as success, and a failure
  deleting one still attempts the other before reporting the run as incomplete.

### Manual cleanup

```bash
aws amplify delete-branch --app-id "$AMPLIFY_APP_ID" \
  --branch-name 'amplify-preview/pr-12' --region "$AWS_REGION"

gh api --method DELETE repos/benstraw/benstrawbridge.com/git/refs/heads/amplify-preview/pr-12
```

List anything left over:

```bash
aws amplify list-branches --app-id "$AMPLIFY_APP_ID" --region "$AWS_REGION" \
  --query "branches[?starts_with(branchName, 'amplify-preview/')].branchName"

git ls-remote --heads origin 'refs/heads/amplify-preview/*'
```

## Troubleshooting

| Symptom | Cause |
| --- | --- |
| Adding the label does nothing | The workflow is not on the default branch yet, or the label is not exactly `deploy-preview` |
| `Unaudited Amplify environment variables` | Classify them in `.github/amplify-preview-env.json` |
| `Could not read Amplify app` | `AMPLIFY_APP_ID` / `AWS_REGION` wrong, or the role lacks `amplify:GetApp` |
| `not authorized to perform sts:AssumeRoleWithWebIdentity` | Trust policy `sub` does not match `repo:benstraw/benstrawbridge.com:environment:amplify-preview`, or the job is missing `id-token: write` |
| `comes from a fork` | Expected — fork previews are out of scope |
| `at least write access is required` | The person who added the label has triage or read access |
| `is connected to <other repo>` | `AMPLIFY_APP_ID` points at a different application |
| `branch auto-detection ... matches` | The app would auto-create a branch for the preview ref; narrow the pattern or disable auto-detection |
| Amplify job fails immediately | Check the build in the Amplify console; the preview uses the same `amplify.yml` as production |

## Assumptions about the existing Amplify application

These could not be verified from the session that wrote this feature — it had no
AWS access. Rather than hard-coding values, the workflow reads them at run time and
fails loudly when one does not hold. Confirm them once during setup.

1. **One Amplify app, connected to this Git repository.** Verified each run by
   comparing `app.repository` with the workflow's repository; a mismatch aborts.
2. **The production branch is the app's `productionBranch`,** and is never written
   to. It is read once per deployment to copy `framework`; IAM denies any write.
3. **The build specification comes from `amplify.yml` in the repository** (or the
   app-level build spec). Preview branches set no branch-level build spec, so they
   build exactly like production. If the production branch carries its own
   branch-level build spec, the run warns — decide then whether the preview needs
   the same override.
4. **The app platform is `WEB`** (static Hugo output). Another platform is a
   warning, not a failure; an SSR app may need a branch-level compute role.
5. **Branch auto-detection is off.** If it is on and a pattern matches
   `amplify-preview/pr-*`, the deployment aborts rather than let Amplify create
   uncontrolled branches from the temporary refs.
6. **Native pull-request previews stay off.** Preview branches set
   `enablePullRequestPreview=false` explicitly; the app-level setting is not
   changed.
7. **No per-branch backend environment.** Previews attach none, so a Gen 1/Gen 2
   backend would need separate design.
8. **Previews use the default `amplifyapp.com` domain only.** No custom-domain
   sub-domain is associated and no DNS record is created.
9. **`AWS_REGION` is the app's region.** The app id is region-scoped, so a mismatch
   surfaces immediately as "could not read Amplify app".

## Testing without AWS

`npm run test:amplify-preview` runs the deploy, cleanup and authorisation scripts
against mock `aws`, `gh` and `curl` binaries and asserts the calls they make: first
deployment, re-deployment onto an existing branch, job failure, cancellation,
timeout, the environment-variable gate, the production safeguards, idempotent
cleanup, partial cleanup failure, and every authorisation rejection. It touches no
network and no AWS account.

## Rollback

1. Delete `.github/workflows/amplify-preview.yml`,
   `.github/workflows/amplify-preview-cleanup.yml`,
   `.github/amplify-preview-env.json`, `scripts/amplify-preview/`, this document,
   and the `test:amplify-preview` entry in `package.json`.
2. Delete any remaining `amplify-preview/pr-*` Amplify branches and Git branches
   (commands above).
3. Delete the `github-amplify-preview` IAM role, the `amplify-preview` GitHub
   environment, the three repository variables, and the `deploy-preview` label.

Production configuration is untouched by all of this.

## References

- [AWS Amplify pull request previews](https://docs.aws.amazon.com/amplify/latest/userguide/pr-previews.html)
- [`aws amplify create-branch`](https://docs.aws.amazon.com/cli/latest/reference/amplify/create-branch.html)
- [`aws amplify start-job`](https://docs.aws.amazon.com/cli/latest/reference/amplify/start-job.html)
- [Manually running a GitHub workflow](https://docs.github.com/actions/managing-workflow-runs/manually-running-a-workflow)
- [Configuring OpenID Connect in Amazon Web Services](https://docs.github.com/actions/security-for-github-actions/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services)
