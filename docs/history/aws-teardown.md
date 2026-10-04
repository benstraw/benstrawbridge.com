# Historical: AWS teardown

AWS Amplify hosted the site until September 2026, when it moved to Cloudflare
Workers. Amplify is retired. `scripts/aws-teardown/` is kept only as a record
of the one-time cleanup; **don't run it against a new hosting setup**. It can
be deleted in a future cleanup, along with `npm run test:aws-teardown`.

`scripts/aws-teardown/teardown.sh` removed what AWS hosted for the site:

- the Amplify app and its domain association
- the `github-amplify-preview` IAM role
- the GitHub OIDC provider, if nothing else trusted it
- the Route 53 zone, once public NS no longer pointed at awsdns
- unused ACM certificates for the domain
- S3 buckets whose name contains `benstraw`

```bash
AWS_REGION=… scripts/aws-teardown/teardown.sh                      # lists Amplify apps
AMPLIFY_APP_ID=… AWS_REGION=… scripts/aws-teardown/teardown.sh     # inventory, read-only
AMPLIFY_APP_ID=… AWS_REGION=… scripts/aws-teardown/teardown.sh --apply
```

Without `--apply` it changes nothing. It saves every resource's JSON (including
Amplify env vars and redirect rules) to `aws-teardown-backup/` (gitignored).
`--apply` refuses while `www` still answers from CloudFront, requires typing the
app name back, and asks for each bucket name separately. CloudFront
distributions are only printed, with disable-then-delete commands. Written for
macOS's bash 3.2. `npm run test:aws-teardown` runs it against mock `aws` and
`curl`.

GitHub-side leftovers were removed by hand: the `amplify-preview` environment,
the `AWS_PREVIEW_ROLE_ARN` variable, and the `deploy-preview` label.
