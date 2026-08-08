# Eatinity Terraform Import Guide

The active region-selectable root is `environments/production`. Imports must be
performed only after initializing the exact backend for the intended Region and
confirming both `aws_region` and `resource_prefix`. Never import a Canada
resource into the US East state or the reverse.

This Terraform folder is completed for presentation and documentation. It was written safely without running `terraform apply`.

Because many AWS resources already exist, do **not** apply this directly until you import existing resources or review a plan carefully.

## Adopt the manually created Canada Stripe secret

The proven Canada migration created `eatinity-prod-cac1/stripe` manually so the
working payment Lambdas could be moved away from direct secret environment
variables without running Terraform apply. Before any future Canada plan/apply,
initialize the existing Canada backend and import the secret container:

```powershell
terraform -chdir=eatinity-iac/environments/production init -reconfigure `
  -backend-config="bucket=<CANADA_STATE_BUCKET>" `
  -backend-config="key=<CANADA_STATE_KEY>" `
  -backend-config="region=<STATE_BUCKET_REGION>" `
  -backend-config="encrypt=true"

terraform -chdir=eatinity-iac/environments/production output -raw aws_region
terraform -chdir=eatinity-iac/environments/production output -raw resource_prefix
```

Continue only when the outputs are exactly `ca-central-1` and
`eatinity-prod-cac1`. Back up the state, then import by secret name:

```powershell
terraform -chdir=eatinity-iac/environments/production import `
  module.secrets.aws_secretsmanager_secret.stripe `
  eatinity-prod-cac1/stripe
```

The import adopts only the secret metadata/container. Terraform must never be
given `stripe_secret_key`, `stripe_webhook_secret`, or a secret version resource;
therefore the encrypted value remains outside state. After import, run
`terraform plan` and require a no-replacement result for the secret. Do not
apply until the entire regional plan is reviewed.

Recommended safe workflow after presentation:

1. Back up current state.
2. Run `terraform init` only when ready.
3. Import existing resources, for example:

```powershell
terraform import aws_dynamodb_table.products EatinityProducts
terraform import aws_dynamodb_table.orders EatinityOrders
terraform import aws_dynamodb_table.users EatinityUsers
terraform import aws_lambda_function.get_products eatinity-get-products
terraform import aws_lambda_function.create_checkout_session eatinity-create-checkout-session
terraform import aws_lambda_function.stripe_webhook eatinity-stripe-webhook
terraform import aws_lambda_function.user_profile eatinity-user-profile
terraform import aws_s3_bucket.website eatinity-prod-s3-website
terraform import aws_s3_bucket.images eatinity-prod-s3-images
```

API Gateway route/integration imports need API IDs and route IDs from AWS Console. CloudFront import needs the distribution ID.

The consolidated IaC now also declares resources that AWS may already have
created automatically or that were managed by the older `eatinity-backend`
Terraform configuration. Import these before any future apply when they exist:

- S3 bucket policies, versioning, encryption, CORS, and public-access blocks.
- CloudFront origin access control and distribution.
- Route 53 root and `www` aliases when `manage_public_dns = true`.
- Existing Lambda CloudWatch log groups and the API Gateway log group.
- DynamoDB tables, including their indexes and recovery configuration.
- Cognito groups, API Gateway routes/integrations/authorizer/stage, Lambda
  permissions, SES identity/DKIM/mail-from configuration, and SNS topic.

Use the dedicated Lambda execution role declared by the application module.
Do not enable `manage_public_dns` until the existing DNS records and
distribution are in the same reviewed Terraform state.

Presentation talking point:

- Terraform now documents S3 + CloudFront, API Gateway, Lambda, DynamoDB, Cognito JWT authorizer, Stripe webhook integration, SES email, SNS notification, IAM permissions, and CloudWatch logging permissions.
