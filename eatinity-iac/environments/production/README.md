# Eatinity recovery-validation environment

This is a protected, production-equivalent recovery-validation root in
`ca-central-1`. It proves that Eatinity can be rebuilt from Terraform,
application artifacts, and controlled backups without modifying the existing
main-region project.

## Module layout

- `../../modules/identity`: Cognito pool, client, and admin groups
- `../../modules/database`: DynamoDB tables and indexes
- `../../modules/storage`: website and image S3 buckets
- `../../modules/application`: IAM, Lambda, API Gateway, permissions, and logs
- `../../modules/delivery`: CloudFront, website policy, and optional DNS
- `../../modules/operations`: SES and SNS
- `../../modules/recovery_backup`: optional AWS Backup cross-region policy,
  vaults, selection, and service role

## Recovery safety defaults

- Region-aware prefix: `eatinity-prod-cac1`
- The existing `us-east-1` main region is blocked by default
- S3 names include the AWS account ID
- New Cognito resources are created in the test region
- Production DNS and custom certificates are disabled
- DynamoDB and Cognito deletion protection are enabled
- DynamoDB point-in-time recovery and S3 versioning are enabled
- S3 buckets use `force_destroy = false`
- CloudWatch retention is 30 days
- Stripe must use test-mode values
- Resources are tagged `Purpose = DisasterRecoveryValidation` and
  `Disposable = false`

## Important

Use a separate `ca-central-1` state. Do not copy or import either legacy state
file. Before any apply, confirm the plan contains only new resources prefixed
`eatinity-prod-cac1` and no changes to the existing main-region project.

For a later main-region rollout, use a different state and set
`allow_main_region_deployment = true` only after choosing an import or parallel
deployment strategy and reviewing its plan.

The supplied examples are intentionally separate:

- `terraform.tfvars.example` and `backend.hcl.example`: protected
  `ca-central-1` recovery validation with `eatinity-prod-cac1-*` names.
- `terraform.main-region.tfvars.example` and
  `backend.main-region.hcl.example`: protected `us-east-1` rollout with
  `eatinity-prod-use1-*` names.

`backend.hcl.example` is only a values template for a future protected S3
backend; the current root uses a separate local state unless an S3 backend
block is deliberately configured first.

The isolated `ca-central-1` infrastructure has been initialized, validated,
planned, and applied. The next Terraform operation must be a reviewed update
plan for the protection settings above. The migration scripts have not been
run.
