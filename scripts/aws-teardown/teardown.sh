#!/usr/bin/env bash
#
# Removes what AWS was hosting for benstrawbridge.com, once the site is served
# by Cloudflare. See "Retiring AWS" in CLAUDE.md.
#
#   AMPLIFY_APP_ID=… AWS_REGION=… scripts/aws-teardown/teardown.sh           # inventory only
#   AMPLIFY_APP_ID=… AWS_REGION=… scripts/aws-teardown/teardown.sh --apply   # delete
#
# Without --apply this is read-only: it lists every candidate and saves the raw
# JSON to aws-teardown-backup/<timestamp>/ (gitignored). Amplify's environment
# variables and redirect rules land in that backup too, so it is the last copy
# of the app's config.
#
# --apply deletes only what the same run just listed, and only after:
#   1. https://www.<domain>/ answers from Cloudflare with no CloudFront headers;
#   2. you type the Amplify app's name back;
#   3. you type each S3 bucket's name back (a bucket is skipped otherwise).
# A Route 53 zone is skipped while the domain's public NS still point at
# awsdns. CloudFront distributions are listed, never deleted: they have to be
# disabled and redeployed first, so the commands are printed instead.
#
# With AMPLIFY_APP_ID unset it lists the region's Amplify apps and exits.
#
# Written for the bash 3.2 macOS ships: no mapfile, no arrays. Every list is a
# whitespace-separated string, which is safe because none of the identifiers
# involved (ARNs, zone ids, bucket and policy names, domains) can contain spaces.
#
set -euo pipefail

DOMAIN="${DOMAIN:-benstrawbridge.com}"
PREVIEW_ROLE_NAME="${PREVIEW_ROLE_NAME:-github-amplify-preview}"
BUCKET_MATCH="${BUCKET_MATCH:-benstraw}"
OIDC_HOST="token.actions.githubusercontent.com"

APPLY=false
for arg in "$@"; do
  case "$arg" in
    --apply) APPLY=true ;;
    -h|--help) sed -n '2,22p' "$0"; exit 0 ;;
    *) echo "unknown argument: $arg" >&2; exit 2 ;;
  esac
done

: "${AWS_REGION:?set AWS_REGION to the region of the Amplify app}"
export AWS_REGION AWS_PAGER=""

aws_json() { aws "$@" --output json; }
say() { printf '%s\n' "$*"; }
section() { printf '\n== %s\n' "$*"; }
die() { printf 'aws-teardown: %s\n' "$*" >&2; exit 1; }

# Every record in the zone except the apex NS and SOA, which Route 53 owns.
JQ_ZONE_CHANGES='{Changes: [.ResourceRecordSets[]
  | select((.Name == $d and (.Type == "NS" or .Type == "SOA")) | not)
  | {Action: "DELETE", ResourceRecordSet: .}]}'
# One delete-objects batch: every version and delete marker on the page.
JQ_VERSION_BATCH='{Objects: [((.Versions // [])[], (.DeleteMarkers // [])[]) | {Key, VersionId}], Quiet: true}'

if [ -z "${AMPLIFY_APP_ID:-}" ]; then
  say "AMPLIFY_APP_ID is not set. Amplify apps in ${AWS_REGION}:"
  aws_json amplify list-apps | jq -r '.apps[] | "  \(.appId)  \(.name)  \(.defaultDomain)"'
  exit 1
fi

BACKUP="aws-teardown-backup/$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -p "$BACKUP"

# ── Inventory (read-only) ────────────────────────────────────────────────────

section "Amplify app ${AMPLIFY_APP_ID}"
APP_NAME=""
DOMAIN_ASSOCS=""
if aws_json amplify get-app --app-id "$AMPLIFY_APP_ID" >"$BACKUP/amplify-app.json" 2>/dev/null; then
  APP_NAME="$(jq -r '.app.name' "$BACKUP/amplify-app.json")"
  say "  name:           ${APP_NAME}"
  jq -r '"  default domain: \(.app.defaultDomain)",
         "  env vars:       \(.app.environmentVariables // {} | keys | join(", "))",
         "  redirect rules: \(.app.customRules // [] | length)"' "$BACKUP/amplify-app.json"
  aws_json amplify list-branches --app-id "$AMPLIFY_APP_ID" >"$BACKUP/amplify-branches.json"
  jq -r '.branches[] | "  branch:         \(.branchName)"' "$BACKUP/amplify-branches.json"
  aws_json amplify list-webhooks --app-id "$AMPLIFY_APP_ID" >"$BACKUP/amplify-webhooks.json"
  aws_json amplify list-domain-associations --app-id "$AMPLIFY_APP_ID" >"$BACKUP/amplify-domains.json"
  DOMAIN_ASSOCS="$(jq -r '.domainAssociations[].domainName' "$BACKUP/amplify-domains.json")"
  for d in $DOMAIN_ASSOCS; do say "  custom domain:  $d"; done
else
  rm -f "$BACKUP/amplify-app.json"
  say "  not found (already deleted?)"
fi

section "IAM role ${PREVIEW_ROLE_NAME}"
ROLE_EXISTS=false
INLINE_POLICIES=""
ATTACHED_POLICIES=""
if aws_json iam get-role --role-name "$PREVIEW_ROLE_NAME" >"$BACKUP/iam-role.json" 2>/dev/null; then
  ROLE_EXISTS=true
  INLINE_POLICIES="$(aws_json iam list-role-policies --role-name "$PREVIEW_ROLE_NAME" | jq -r '.PolicyNames[]')"
  for p in $INLINE_POLICIES; do
    aws_json iam get-role-policy --role-name "$PREVIEW_ROLE_NAME" --policy-name "$p" >"$BACKUP/iam-inline-$p.json"
    say "  inline policy:   $p"
  done
  ATTACHED_POLICIES="$(aws_json iam list-attached-role-policies --role-name "$PREVIEW_ROLE_NAME" | jq -r '.AttachedPolicies[].PolicyArn')"
  for p in $ATTACHED_POLICIES; do say "  attached policy: $p"; done
else
  rm -f "$BACKUP/iam-role.json"
  say "  not found"
fi

section "GitHub OIDC provider"
OIDC_ARN="$(aws_json iam list-open-id-connect-providers \
  | jq -r --arg h "$OIDC_HOST" '.OpenIDConnectProviderList[].Arn | select(endswith($h))' | head -n1)"
OIDC_OTHER_USERS=""
if [ -n "$OIDC_ARN" ]; then
  say "  ${OIDC_ARN}"
  OIDC_OTHER_USERS="$(aws_json iam list-roles | jq -r --arg arn "$OIDC_ARN" --arg me "$PREVIEW_ROLE_NAME" \
    '.Roles[] | select(.RoleName != $me)
     | select((.AssumeRolePolicyDocument | tostring) | contains($arn)) | .RoleName')"
  if [ -n "$OIDC_OTHER_USERS" ]; then
    say "  KEEP: also trusted by" $OIDC_OTHER_USERS
  fi
else
  say "  not found"
fi

section "Route 53 hosted zones for ${DOMAIN}"
ZONES="$(aws_json route53 list-hosted-zones-by-name --dns-name "$DOMAIN" \
  | jq -r --arg d "${DOMAIN}." '.HostedZones[] | select(.Name == $d) | .Id | sub("^/hostedzone/"; "")')"
for z in $ZONES; do
  aws_json route53 list-resource-record-sets --hosted-zone-id "$z" >"$BACKUP/route53-$z.json"
  say "  $z ($(jq '.ResourceRecordSets | length' "$BACKUP/route53-$z.json") records)"
done
[ -n "$ZONES" ] || say "  none"

section "ACM certificates for ${DOMAIN}"
CERTS=""
for r in $(printf '%s\n' us-east-1 "$AWS_REGION" | sort -u); do
  for arn in $(aws_json acm list-certificates --region "$r" \
      | jq -r --arg d "$DOMAIN" '.CertificateSummaryList[] | select(.DomainName | endswith($d)) | .CertificateArn'); do
    in_use="$(aws_json acm describe-certificate --region "$r" --certificate-arn "$arn" | jq '.Certificate.InUseBy | length')"
    if [ "$in_use" = "0" ]; then
      CERTS="${CERTS} ${r}|${arn}"
      say "  $arn"
    else
      say "  KEEP (in use by ${in_use}): $arn"
    fi
  done
done
[ -n "$CERTS" ] || say "  none"

section "S3 buckets matching '${BUCKET_MATCH}'"
BUCKETS="$(aws_json s3api list-buckets | jq -r --arg m "$BUCKET_MATCH" '.Buckets[].Name | select(contains($m))')"
for b in $BUCKETS; do
  say "  $b ($(aws_json s3api list-objects-v2 --bucket "$b" | jq '.Contents // [] | length') objects)"
done
[ -n "$BUCKETS" ] || say "  none"

section "CloudFront distributions aliased to ${DOMAIN}"
DISTS="$(aws_json cloudfront list-distributions | jq -r --arg d "$DOMAIN" \
  '.DistributionList.Items // [] | .[] | select((.Aliases.Items // []) | any(endswith($d))) | .Id')"
for d in $DISTS; do say "  $d"; done
[ -n "$DISTS" ] || say "  none"

say ""
say "Backup written to ${BACKUP}/"

if ! $APPLY; then
  say "Inventory only; nothing was changed. Re-run with --apply to delete the above."
  exit 0
fi

# ── Preconditions for --apply ────────────────────────────────────────────────

section "Checking Cloudflare serves https://www.${DOMAIN}/"
headers="$(curl -sSI --max-time 20 "https://www.${DOMAIN}/" | tr '[:upper:]' '[:lower:]')" \
  || die "could not reach https://www.${DOMAIN}/"
if grep -qE '^(x-amz-cf-|via:.*cloudfront|x-cache:.*cloudfront)' <<<"$headers"; then
  die "www.${DOMAIN} is still answered by CloudFront/Amplify. Cut over first; nothing deleted."
fi
grep -q '^server: cloudflare' <<<"$headers" \
  || die "www.${DOMAIN} is not served by Cloudflare; nothing deleted."
say "  ok"

expected="${APP_NAME:-delete}"
printf '\nType %s to delete everything listed above: ' "$expected"
read -r answer
[ "$answer" = "$expected" ] || die "confirmation did not match; nothing deleted."

# ── Delete ───────────────────────────────────────────────────────────────────

if [ -n "$APP_NAME" ]; then
  section "Deleting Amplify app"
  for d in $DOMAIN_ASSOCS; do
    aws amplify delete-domain-association --app-id "$AMPLIFY_APP_ID" --domain-name "$d" >/dev/null
    say "  domain association $d"
  done
  aws amplify delete-app --app-id "$AMPLIFY_APP_ID" >/dev/null
  say "  app ${AMPLIFY_APP_ID}"
fi

if $ROLE_EXISTS; then
  section "Deleting IAM role ${PREVIEW_ROLE_NAME}"
  for p in $INLINE_POLICIES; do
    aws iam delete-role-policy --role-name "$PREVIEW_ROLE_NAME" --policy-name "$p"
  done
  for p in $ATTACHED_POLICIES; do
    aws iam detach-role-policy --role-name "$PREVIEW_ROLE_NAME" --policy-arn "$p"
  done
  aws iam delete-role --role-name "$PREVIEW_ROLE_NAME"
  say "  done"
fi

if [ -n "$OIDC_ARN" ] && [ -z "$OIDC_OTHER_USERS" ]; then
  section "Deleting OIDC provider"
  aws iam delete-open-id-connect-provider --open-id-connect-provider-arn "$OIDC_ARN"
  say "  $OIDC_ARN"
fi

if [ -n "$ZONES" ]; then
  section "Deleting Route 53 zones"
  ns="$(curl -sS --max-time 20 -H 'accept: application/dns-json' \
    "https://cloudflare-dns.com/dns-query?name=${DOMAIN}&type=NS" | jq -r '[.Answer[]?.data] | join(" ")')" || ns=""
  if [ -z "$ns" ] || grep -qi 'awsdns' <<<"$ns"; then
    say "  SKIPPED: public NS for ${DOMAIN} is '${ns:-unknown}', not Cloudflare."
  else
    for z in $ZONES; do
      changes="$(jq -c --arg d "${DOMAIN}." "$JQ_ZONE_CHANGES" "$BACKUP/route53-$z.json")"
      if [ "$(jq '.Changes | length' <<<"$changes")" -gt 0 ]; then
        aws route53 change-resource-record-sets --hosted-zone-id "$z" --change-batch "$changes" >/dev/null
      fi
      aws route53 delete-hosted-zone --id "$z" >/dev/null
      say "  $z"
    done
  fi
fi

if [ -n "$CERTS" ]; then
  section "Deleting ACM certificates"
  for c in $CERTS; do
    aws acm delete-certificate --region "${c%%|*}" --certificate-arn "${c#*|}"
    say "  ${c#*|}"
  done
fi

for b in $BUCKETS; do
  section "S3 bucket ${b}"
  printf 'Type the bucket name to empty and delete it (anything else skips): '
  read -r answer
  if [ "$answer" != "$b" ]; then say "  skipped"; continue; fi
  # Versioned buckets keep every old version and delete marker; a bucket is
  # only deletable once all of them are gone.
  while :; do
    batch="$(aws_json s3api list-object-versions --bucket "$b" --max-items 1000 | jq -c "$JQ_VERSION_BATCH")"
    [ "$(jq '.Objects | length' <<<"$batch")" -gt 0 ] || break
    aws s3api delete-objects --bucket "$b" --delete "$batch" >/dev/null
  done
  aws s3api delete-bucket --bucket "$b"
  say "  deleted"
done

if [ -n "$DISTS" ]; then
  section "CloudFront (not deleted; run these by hand)"
  for d in $DISTS; do
    say "  aws cloudfront get-distribution-config --id $d > cf-$d.json"
    say "    # edit: keep only .DistributionConfig, set .Enabled = false; note the ETag"
    say "  aws cloudfront update-distribution --id $d --if-match <ETag> --distribution-config file://<edited>.json"
    say "  aws cloudfront wait distribution-deployed --id $d"
    say "  aws cloudfront delete-distribution --id $d --if-match <new ETag>"
  done
fi

say ""
say "Done. Backup kept in ${BACKUP}/."
