# Eatinity Infrastructure as Code

This folder contains Terraform code for the Eatinity secure cloud e-commerce demo platform.

## Current structure

The active configuration has been moved to:

```text
environments/production/
```

Reusable Terraform resources are organized under:

```text
modules/
  identity/
  database/
  storage/
  application/
  delivery/
  operations/
  recovery_backup/
```

Run recovery-validation Terraform commands from that directory, not from
the `eatinity-iac` root. The legacy state snapshots remain at the root for
reference only and are not part of the recovery-validation working directory.

The isolated recovery stack has been initialized, validated, planned, and
applied. AWS-native backup/recovery tooling exists under `migration/` but has
not been run.

## Covered AWS services

- Amazon S3 for React frontend hosting and product images
- Amazon CloudFront for HTTPS CDN delivery
- Amazon API Gateway HTTP API
- AWS Lambda for products, Stripe checkout, Stripe webhook, and user profile/order APIs
- Amazon DynamoDB for products, categories, orders, audit records, and users
- Amazon Cognito JWT authorizer for protected customer APIs
- Amazon SES for order confirmation email
- Amazon SNS for operational notifications
- AWS IAM permissions for Lambda runtime access
- CloudWatch Logs permissions through Lambda runtime policy
- CloudWatch log-group retention and API Gateway structured access logs
- DynamoDB point-in-time recovery and deletion protection
- S3 versioning and server-side encryption
- CloudFront OAC website-bucket policy and public product-image read policy
- Optional ACM certificate input and Route 53 aliases

## Important safety note

The recovery-validation root manages isolated resources in `ca-central-1`;
it must not import or reuse the existing main-region resources. Review a
create-only plan before any apply.

No Terraform apply/destroy command was run while preparing these files.

## Current-account verification status

The earlier IaC was compared with the application configuration and with local
Terraform state snapshots. A live AWS comparison still requires valid AWS CLI
credentials for the intended account. State snapshots in this workspace refer
to more than one AWS account, so they must not be treated as proof of the
currently active account.

The existing production storefront currently expects:

- API base URL: the existing `eatinity-products-api` HTTP API
- Image bucket: `eatinity-prod-s3-images`
- Cognito pool: the IDs configured in `terraform.tfvars.example`
- Public API routes: `GET /products` and `GET /categories`

Before any future Terraform operation, confirm the active AWS account ID and
the intended region. `IMPORT_GUIDE.md` applies only to the later existing-resource
import workflow, not this isolated recovery-validation environment.
