# eatinity Complete Regional Deployment and Disaster-Recovery Runbook

This runbook uses the repository root `bootstrap.sh` as the single entry point.
It can prepare and validate a recovery deployment in any supported AWS Region,
start AWS Backup jobs in the source Region, copy recovery points, restore them
in the selected Region, migrate application data, recover Cognito and SES,
deploy the frontend, and run smoke tests.

The script does **not** run `terraform apply` by default. Every mutating action
requires both `--execute` and `--approve-region <destination-region>`. This
prevents an accidental command from changing the existing primary or recovery
environment.

## 1. Recovery model and important limits

- Default source Region: `us-east-1`.
- Example destination Region: `ca-central-1`.
- The source and destination must normally be different.
- Destination names are generated from the Region, account, project, and
  environment. For example, `ca-central-1` produces the `eatinity-prod-cac1`
  prefix.
- Terraform creates a new Cognito pool. Cognito passwords, sessions, refresh
  tokens, and MFA secrets cannot be copied. Recovered users must establish a
  new password.
- SES identities, sandbox/production status, quotas, and verification are
  regional and require separate validation.
- Public DNS is disabled by default. A recovery drill should use its CloudFront
  URL. DNS cutover is a separate business decision.
- Terraform creates the Secrets Manager container but never writes Stripe
  values into Terraform state. Add only test-mode credentials through a local,
  ignored JSON file after infrastructure deployment.
- AWS Backup and restore operations create chargeable resources.

## 2. Required tools and permissions

Install these tools on the operator workstation or an approved automation host:

- Bash 4 or later (Git Bash, WSL, Linux, macOS, or AWS CloudShell).
- AWS CLI v2.
- Terraform 1.5 or later.
- PowerShell 7 (`pwsh`) because the validated recovery job implementations are
  PowerShell scripts called by `bootstrap.sh`.
- Node.js and npm.
- Python 3.
- `zip`, `jq`, and `curl`.

The active AWS identity needs permission to create the selected recovery stack,
the protected Terraform backend, AWS Backup vaults/plans/roles, and the
destination services. The script prints the active identity during preflight.
Never use an account or role that you have not verified.

## 3. Select the recovery Region

Choose a Region using these checks:

1. It must be different from the failed source Region.
2. Confirm that API Gateway, Lambda, DynamoDB, S3, Cognito, Secrets Manager,
   CloudWatch, SNS, SES, AWS Backup, and CloudFront deployment are supported.
3. Confirm business, latency, regulatory, and data-residency requirements.
4. Confirm AWS Backup cross-Region copy support from the source Region.
5. Confirm service quotas, especially Lambda, CloudFront, DynamoDB, Cognito,
   SES, and ACM.
6. Confirm the Region is not affected by the same incident.
7. Record the decision, approver, incident time, target RPO, and target RTO.

Set values for the session:

```bash
export SOURCE_REGION="us-east-1"
export DESTINATION_REGION="ca-central-1"
export STATE_REGION="ca-central-1"
export STATE_BUCKET="REPLACE-WITH-GLOBALLY-UNIQUE-STATE-BUCKET"
export LOCK_TABLE="eatinity-terraform-locks"
export BACKUP_OPERATOR_USER="marjan-admin"
```

The state bucket must be outside the recoverable application stack. Protect it
with versioning, encryption, public-access blocking, restricted IAM, and a
separate backup/replication policy. Do not copy old application state into a new
regional deployment.

## 4. Inspect the command without making changes

```bash
chmod +x ./bootstrap.sh
./bootstrap.sh --help
```

Create ignored regional configuration files:

```bash
./bootstrap.sh configure \
  --source-region "$SOURCE_REGION" \
  --destination-region "$DESTINATION_REGION" \
  --state-region "$STATE_REGION" \
  --state-bucket "$STATE_BUCKET" \
  --lock-table "$LOCK_TABLE" \
  --backup-operator-user "$BACKUP_OPERATOR_USER"
```

Files are written under `.eatinity-recovery/<destination-region>/` and are
ignored by Git. Review `terraform.tfvars` and `backend.hcl`. Confirm every
source table, bucket, Cognito pool, Region, and state value before continuing.

## 5. Create the protected Terraform backend

This is a one-time mutation. It creates or configures the state bucket and
DynamoDB locking table. The bucket name must be globally unique.

```bash
./bootstrap.sh create-state-backend \
  --destination-region "$DESTINATION_REGION" \
  --state-region "$STATE_REGION" \
  --state-bucket "$STATE_BUCKET" \
  --lock-table "$LOCK_TABLE" \
  --backup-operator-user "$BACKUP_OPERATOR_USER" \
  --execute --approve-region "$DESTINATION_REGION"
```

Verify:

```bash
aws s3api get-bucket-versioning \
  --bucket "$STATE_BUCKET" --region "$STATE_REGION"

aws s3api get-public-access-block \
  --bucket "$STATE_BUCKET" --region "$STATE_REGION"

aws dynamodb describe-table \
  --table-name "$LOCK_TABLE" --region "$STATE_REGION" \
  --query 'Table.[TableName,TableStatus]'
```

## 6. Run read-only preflight checks

```bash
./bootstrap.sh preflight \
  --source-region "$SOURCE_REGION" \
  --destination-region "$DESTINATION_REGION" \
  --state-region "$STATE_REGION" \
  --state-bucket "$STATE_BUCKET" \
  --lock-table "$LOCK_TABLE" \
  --backup-operator-user "$BACKUP_OPERATOR_USER"
```

Expected results:

- Correct AWS account and operator ARN.
- Source and destination Regions are different.
- All five source DynamoDB tables are `ACTIVE`.
- Both source S3 buckets have Versioning enabled.
- DynamoDB and S3 are enabled in AWS Backup Region settings.
- No Terraform apply occurs.

If a source name differs, override it explicitly, for example:

```bash
./bootstrap.sh preflight \
  --destination-region "$DESTINATION_REGION" \
  --backup-operator-user "$BACKUP_OPERATOR_USER" \
  --state-bucket "$STATE_BUCKET" \
  --source-products-table "ACTUAL_PRODUCTS_TABLE" \
  --source-images-bucket "ACTUAL_IMAGES_BUCKET"
```

## 7. Validate application and infrastructure locally

This packages Lambda functions, runs frontend lint/build, runs backend tests,
formats and validates Terraform, but does not access a deployment backend or
apply infrastructure.

```bash
./bootstrap.sh validate \
  --destination-region "$DESTINATION_REGION" \
  --backup-operator-user "$BACKUP_OPERATOR_USER"
```

## 8. Create and review the Terraform plan

```bash
./bootstrap.sh plan \
  --source-region "$SOURCE_REGION" \
  --destination-region "$DESTINATION_REGION" \
  --state-region "$STATE_REGION" \
  --state-bucket "$STATE_BUCKET" \
  --lock-table "$LOCK_TABLE" \
  --backup-operator-user "$BACKUP_OPERATOR_USER"
```

Review:

```bash
less ".eatinity-recovery/$DESTINATION_REGION/plan.txt"
```

Approval checklist:

- The AWS account is correct.
- Destination resources use the expected Region-derived prefix.
- No existing primary application resource is updated or deleted.
- Source-Region changes are limited to explicitly approved AWS Backup vault,
  plan, selection, IAM service role/policy, and operator attachment.
- `force_destroy_buckets = false`.
- deletion protection, DynamoDB PITR, S3 versioning, and encryption remain on.
- public DNS and the custom domain remain off for a drill.
- SES and DNS are off unless separately approved.
- The plan contains no secret values.

Do not apply if any delete, replacement, unexpected import, primary application
change, or unknown resource appears.

## 9. Apply the exact reviewed plan

Only after written approval:

```bash
./bootstrap.sh apply \
  --source-region "$SOURCE_REGION" \
  --destination-region "$DESTINATION_REGION" \
  --state-region "$STATE_REGION" \
  --state-bucket "$STATE_BUCKET" \
  --lock-table "$LOCK_TABLE" \
  --backup-operator-user "$BACKUP_OPERATOR_USER" \
  --execute --approve-region "$DESTINATION_REGION"
```

The script applies only the saved `.tfplan`. It does not create a new plan at
apply time.

Display outputs:

```bash
./bootstrap.sh outputs \
  --destination-region "$DESTINATION_REGION" \
  --state-region "$STATE_REGION" \
  --state-bucket "$STATE_BUCKET" \
  --lock-table "$LOCK_TABLE" \
  --backup-operator-user "$BACKUP_OPERATOR_USER"
```

Record the destination table names, buckets, Cognito pool, API URL, CloudFront
URL, backup vaults, and backup role ARN.

## 10. Add the Stripe test secret outside Terraform

First obtain the destination webhook URL:

```bash
terraform -chdir=eatinity-iac/environments/production \
  output -raw stripe_webhook_url
```

In Stripe **Test mode**, create a separate webhook event destination for this
exact recovery URL and subscribe it to `checkout.session.completed`. Do not
reuse the main-region endpoint signing secret: each Stripe webhook endpoint has
its own `whsec_...` signing secret. Copy the recovery endpoint's signing secret
only into the destination Region's Secrets Manager value. The Stripe secret API
key can remain the approved test-mode key.

If this step is missing, checkout can create an order in the destination table,
but the order stays `Pending Payment`. Sales reports intentionally query only
orders with `paymentStatus = Paid` and a `paidAt` value, so every report will
correctly show zero until the regional webhook processes a successful payment.

Create a local file that is ignored and never committed:

```bash
cat > stripe-secret.json <<'JSON'
{
  "stripe_secret_key": "REPLACE_WITH_STRIPE_TEST_KEY",
  "stripe_webhook_secret": "REPLACE_WITH_STRIPE_TEST_WEBHOOK_SECRET"
}
JSON
```

Get the created secret name and write the value:

```bash
SECRET_NAME=$(terraform -chdir=eatinity-iac/environments/production \
  output -raw stripe_secret_name)

aws secretsmanager put-secret-value \
  --secret-id "$SECRET_NAME" \
  --secret-string file://stripe-secret.json \
  --region "$DESTINATION_REGION" \
  --no-cli-pager
```

Delete the local file securely after validation. Never print or screenshot the
secret value.

If the secret was created manually during an incident or controlled migration,
do not run Terraform apply afterward until the existing container is imported
into the correct regional state. For Canada Central, follow
`eatinity-iac/IMPORT_GUIDE.md` and import
`eatinity-prod-cac1/stripe` to
`module.secrets.aws_secretsmanager_secret.stripe`. The secret value remains
outside Terraform state.

Run the read-only regional payment diagnostic:

```bash
./bootstrap.sh payment-check \
  --source-region "$SOURCE_REGION" \
  --destination-region "$DESTINATION_REGION" \
  --state-region "$STATE_REGION" \
  --state-bucket "$STATE_BUCKET" \
  --lock-table "$LOCK_TABLE" \
  --backup-operator-user "$BACKUP_OPERATOR_USER"
```

It verifies the destination orders table, the sales-report index, secret
metadata (never the secret value), and payment-status counts. If only pending
orders exist, inspect the recovery endpoint in Stripe Workbench/Webhooks, resend
its `checkout.session.completed` test event, and inspect the destination webhook
Lambda logs. Never change the payment status manually: Stripe confirmation must
remain the source of truth.

## 11. Start native source backups

This starts seven jobs: five DynamoDB tables and two S3 buckets.

```bash
./bootstrap.sh start-backups \
  --source-region "$SOURCE_REGION" \
  --destination-region "$DESTINATION_REGION" \
  --state-region "$STATE_REGION" \
  --state-bucket "$STATE_BUCKET" \
  --lock-table "$LOCK_TABLE" \
  --backup-operator-user "$BACKUP_OPERATOR_USER" \
  --execute --approve-region "$DESTINATION_REGION"
```

The job IDs are written under the ignored directory:

```text
eatinity-iac/migration/job-records/backup-<UTC timestamp>.json
```

For every ID, check status:

```bash
./bootstrap.sh job-status \
  --destination-region "$DESTINATION_REGION" \
  --state-region "$STATE_REGION" --state-bucket "$STATE_BUCKET" \
  --lock-table "$LOCK_TABLE" --backup-operator-user "$BACKUP_OPERATOR_USER" \
  --job-type Backup --job-id "BACKUP_JOB_ID"
```

Do not start a copy until `State` is `COMPLETED`. Record completion time and the
`RecoveryPointArn`. If a job is `FAILED`, record its status message and correct
the prerequisite before retrying.

## 12. Copy every completed recovery point

Run once per completed source recovery point:

```bash
./bootstrap.sh start-copy \
  --destination-region "$DESTINATION_REGION" \
  --state-region "$STATE_REGION" --state-bucket "$STATE_BUCKET" \
  --lock-table "$LOCK_TABLE" --backup-operator-user "$BACKUP_OPERATOR_USER" \
  --recovery-point-arn "SOURCE_RECOVERY_POINT_ARN" \
  --execute --approve-region "$DESTINATION_REGION"
```

Monitor each copy:

```bash
./bootstrap.sh job-status \
  --destination-region "$DESTINATION_REGION" \
  --state-region "$STATE_REGION" --state-bucket "$STATE_BUCKET" \
  --lock-table "$LOCK_TABLE" --backup-operator-user "$BACKUP_OPERATOR_USER" \
  --job-type Copy --job-id "COPY_JOB_ID"
```

After `COMPLETED`, record the destination recovery point ARN. A copied recovery
point, not the source ARN, is used for destination restore.

You can also list destination recovery points directly:

```bash
DESTINATION_VAULT=$(terraform -chdir=eatinity-iac/environments/production \
  output -json backup_recovery | jq -r '.destination_vault_name')

aws backup list-recovery-points-by-backup-vault \
  --backup-vault-name "$DESTINATION_VAULT" \
  --region "$DESTINATION_REGION" \
  --output table --no-cli-pager
```

## 13. Restore into isolated drill targets

Use one shared UTC suffix for the five DynamoDB drill tables:

```bash
export RESTORE_SUFFIX=$(date -u +%Y%m%d)
```

Example DynamoDB restore:

```bash
./bootstrap.sh start-restore \
  --destination-region "$DESTINATION_REGION" \
  --state-region "$STATE_REGION" --state-bucket "$STATE_BUCKET" \
  --lock-table "$LOCK_TABLE" --backup-operator-user "$BACKUP_OPERATOR_USER" \
  --recovery-point-arn "COPIED_PRODUCTS_RECOVERY_POINT_ARN" \
  --resource-type DynamoDB \
  --restore-target "eatinity-recovery-drill-products-$RESTORE_SUFFIX" \
  --execute --approve-region "$DESTINATION_REGION"
```

Repeat with logical names `categories`, `orders`, `audit`, and `users`.

For S3, restore to the Terraform-created versioned destination bucket. Obtain
its name first:

```bash
IMAGES_BUCKET=$(terraform -chdir=eatinity-iac/environments/production \
  output -raw images_bucket_name)
WEBSITE_BUCKET=$(terraform -chdir=eatinity-iac/environments/production \
  output -raw website_bucket_name)
```

Example S3 restore:

```bash
./bootstrap.sh start-restore \
  --destination-region "$DESTINATION_REGION" \
  --state-region "$STATE_REGION" --state-bucket "$STATE_BUCKET" \
  --lock-table "$LOCK_TABLE" --backup-operator-user "$BACKUP_OPERATOR_USER" \
  --recovery-point-arn "COPIED_IMAGES_RECOVERY_POINT_ARN" \
  --resource-type S3 --restore-target "$IMAGES_BUCKET" \
  --execute --approve-region "$DESTINATION_REGION"
```

Monitor every restore using `job-status --job-type Restore`. Never migrate or
publish data until all relevant restore jobs are `COMPLETED`.

## 14. Validate restored data before promotion

For each DynamoDB drill table:

```bash
aws dynamodb describe-table \
  --table-name "eatinity-recovery-drill-products-$RESTORE_SUFFIX" \
  --region "$DESTINATION_REGION" --no-cli-pager

aws dynamodb scan \
  --table-name "eatinity-recovery-drill-products-$RESTORE_SUFFIX" \
  --select COUNT --region "$DESTINATION_REGION" --no-cli-pager
```

Compare source and restored item counts, key schema, local/global secondary
indexes, encryption, TTL configuration if used, and representative business
queries. A count alone is not sufficient.

For S3:

```bash
aws s3api get-bucket-versioning \
  --bucket "$IMAGES_BUCKET" --region "$DESTINATION_REGION"

aws s3 ls "s3://$IMAGES_BUCKET" --recursive \
  --region "$DESTINATION_REGION" --summarize
```

Compare expected key prefixes, object counts, sample checksums/ETags where
appropriate, encryption, and application image retrieval.

## 15. Copy validated DynamoDB data to application tables

This action refuses a non-empty or inconsistent destination. Run it only after
all five drill tables share the same `YYYYMMDD` suffix and validation passed.

```bash
./bootstrap.sh migrate-dynamodb \
  --destination-region "$DESTINATION_REGION" \
  --state-region "$STATE_REGION" --state-bucket "$STATE_BUCKET" \
  --lock-table "$LOCK_TABLE" --backup-operator-user "$BACKUP_OPERATOR_USER" \
  --restore-suffix "$RESTORE_SUFFIX" \
  --execute --approve-region "$DESTINATION_REGION"
```

The existing migration implementation batches writes, retries unprocessed
items, checks destination state, validates final counts, and writes an ignored
evidence record.

## 16. Recover Cognito users and groups

```bash
./bootstrap.sh sync-cognito \
  --source-region "$SOURCE_REGION" \
  --destination-region "$DESTINATION_REGION" \
  --state-region "$STATE_REGION" --state-bucket "$STATE_BUCKET" \
  --lock-table "$LOCK_TABLE" --backup-operator-user "$BACKUP_OPERATOR_USER" \
  --execute --approve-region "$DESTINATION_REGION"
```

The command creates/updates transferable attributes and memberships, suppresses
welcome messages, and then runs validation. It never copies passwords, active
sessions, refresh tokens, or MFA secrets.

During an approved failover, send a reset for a selected test user:

```bash
./bootstrap.sh reset-cognito-user \
  --destination-region "$DESTINATION_REGION" \
  --state-region "$STATE_REGION" --state-bucket "$STATE_BUCKET" \
  --lock-table "$LOCK_TABLE" --backup-operator-user "$BACKUP_OPERATOR_USER" \
  --username "RECOVERED_USERNAME" \
  --execute --approve-region "$DESTINATION_REGION"
```

## 17. Recover SES only after DNS and regional approval

First create and review a new Terraform plan with `--enable-ses`. Add
`--manage-ses-dns` only when Route 53 record changes are explicitly approved.
Apply only the reviewed plan using the normal plan/apply sequence.

Then synchronize templates and validate:

```bash
./bootstrap.sh sync-ses \
  --destination-region "$DESTINATION_REGION" \
  --state-region "$STATE_REGION" --state-bucket "$STATE_BUCKET" \
  --lock-table "$LOCK_TABLE" --backup-operator-user "$BACKUP_OPERATOR_USER" \
  --enable-ses \
  --execute --approve-region "$DESTINATION_REGION"
```

Confirm identity verification, DKIM, MAIL FROM records, templates,
`ProductionAccessEnabled`, `SendingEnabled`, quotas, and approved recipients.

## 18. Deploy the regional frontend

The deployment reads Terraform outputs, creates `runtime-config.js`, builds the
React application, uploads to the destination website bucket, and invalidates
CloudFront.

```bash
./bootstrap.sh deploy-frontend \
  --destination-region "$DESTINATION_REGION" \
  --state-region "$STATE_REGION" --state-bucket "$STATE_BUCKET" \
  --lock-table "$LOCK_TABLE" --backup-operator-user "$BACKUP_OPERATOR_USER" \
  --execute --approve-region "$DESTINATION_REGION"
```

Do not enable the custom domain or public DNS during an isolated drill. If a
real failover later requires DNS, create a separate reviewed plan using
`--use-custom-domain`, the correct ACM certificate ARN, and
`--manage-public-dns`. CloudFront certificates must meet AWS Region placement
requirements. Test the CloudFront URL before DNS cutover.

## 19. Run technical and business validation

Basic smoke test:

```bash
./bootstrap.sh smoke-test \
  --destination-region "$DESTINATION_REGION" \
  --state-region "$STATE_REGION" --state-bucket "$STATE_BUCKET" \
  --lock-table "$LOCK_TABLE" --backup-operator-user "$BACKUP_OPERATOR_USER"
```

Also verify:

1. CloudFront returns the React application over HTTPS.
2. Products and categories APIs return recovered records.
3. Cognito sign-in and required password change work for a recovery test user.
4. Customer profile, address, cart, and order history work.
5. Stripe test checkout creates a session using the destination secret.
6. The destination webhook verifies the Stripe signature and updates the order.
7. Administrator authorization rejects a customer token.
8. Menu, orders, users, reports, and audit functions work.
9. S3 product images load.
10. CloudWatch logs contain the request and no secret values.
11. SNS/SES test notification behavior matches the Region's approval status.
12. No primary Region resource or public DNS record changed during the drill.

## 20. Calculate and record RPO/RTO

Record UTC timestamps for:

- incident declared;
- recovery decision approved;
- selected recovery point created;
- copy started/completed;
- restore started/completed;
- data validation completed;
- Cognito/SES recovery completed;
- frontend/API became available;
- business validation completed;
- recovery declared successful.

Calculations:

```text
Achieved RPO = incident time - selected recovery-point creation time
Achieved RTO = recovery declaration time - incident declaration time
```

Compare achieved values with the 24-hour RPO and four-hour RTO targets. Explain
every miss and assign an improvement action.

## 21. Failover and DNS decision

Do not perform DNS cutover automatically. Obtain incident commander and business
approval after the recovered application passes validation. Confirm certificate,
CloudFront aliases, Route 53 hosted zone, TTL, rollback target, and monitoring.
Use a separately reviewed Terraform plan for DNS. Preserve the previous target
and document the rollback command before changing traffic.

## 22. Cleanup and failback

This bootstrap intentionally has no destroy action. Recovery vaults, restored
tables, versioned buckets, protected Cognito resources, and Terraform state are
not safe targets for an automatic cleanup command.

For cleanup or failback:

1. Obtain written approval.
2. Preserve logs, job records, screenshots, timings, and the final report.
3. Confirm traffic location and data authority.
4. Reconcile data written during recovery.
5. Create and review a dedicated Terraform plan.
6. Remove deletion protection only in a separately approved change.
7. Delete drill resources explicitly and verify exact names/Regions.
8. Never run a broad recursive deletion or `terraform destroy` against an
   unverified state.

## 23. Evidence checklist

Keep these sanitized records:

- Region selection and approval.
- AWS identity/account confirmation.
- Terraform validation and saved plan review.
- Applied plan summary.
- Seven backup job IDs and statuses.
- Seven copy job IDs and destination recovery-point ARNs.
- Restore job IDs and statuses.
- DynamoDB schema/index/count and representative-query validation.
- S3 versioning/object/sample validation.
- Cognito user/group validation and password-reset limitation.
- SES identity/DKIM/template/account status.
- Regional frontend and API smoke tests.
- Customer and administrator workflow tests.
- CloudWatch log evidence.
- Actual RPO/RTO calculations.
- Limitations, lessons learned, and final recovery decision.

Never include access keys, secret values, tokens, private keys, full payment
details, or unnecessary customer information in job records, screenshots,
documentation, or video.
