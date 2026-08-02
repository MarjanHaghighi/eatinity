# Eatinity Secure E-Commerce Platform

Eatinity is a serverless AWS e-commerce application for customers and restaurant
administrators. Customers can register, browse products, manage their profile,
pay through Stripe test mode, and review orders. Authorized staff can manage the
menu, orders, users, reports, and audit records.

## Repository structure

- `.github/workflows/final-project-ci-cd.yml` - one GitHub Actions workflow for
  application checks, Trivy, SonarQube Community Edition, AWS OIDC deployment,
  and post-deployment smoke tests.
- `eatinity-frontend/` - React/Vite customer and administrator interface.
- `eatinity-prod/` - Python Lambda handlers, deployment packages, legacy
  production Terraform, and backend unit tests.
- `eatinity-iac/` - modular Terraform for identity, storage, databases,
  application services, delivery, operations, secrets, and disaster recovery.
- `eatinity-iac/bootstrap/github-oidc/` - separate AWS identity bootstrap for
  GitHub OIDC. This is deliberately outside the application deployment root.
- `eatinity-iac/migration/` - backup, copy, restore, Cognito, SES, deployment,
  and recovery-validation runbooks.
- `docs/` - final report source, evidence register, CI/CD setup guide, and video
  walkthrough plan.
- `Eatinity_Disaster_Recovery_Plan.docx` - detailed recovery plan and drill.

## Application architecture

The React build is stored in Amazon S3 and delivered through CloudFront. Route
53 maps `eatinity.ca` to CloudFront and ACM supplies HTTPS. Amazon Cognito issues
JWTs that API Gateway validates for protected routes. Python Lambda functions
implement product, checkout, webhook, profile, order, menu, user, report, and
audit operations. DynamoDB stores products, categories, orders, users, and audit
events. Stripe operates in test mode. SES and SNS provide email and operational
notifications, while CloudWatch stores logs. AWS Secrets Manager holds Stripe
runtime credentials.

## Local validation

Frontend:

```powershell
cd eatinity-frontend
npm ci
npm run lint
npm run build
```

Backend:

```powershell
cd eatinity-prod
python -m unittest discover -s tests -v
```

Terraform:

```powershell
cd eatinity-iac/environments/production
terraform init -backend=false
terraform fmt -check -recursive
terraform validate
```

## CI/CD and security

The pipeline runs on pushes and pull requests to `main`. It performs frontend
lint/build, Python unit tests, Lambda packaging, Terraform formatting and
validation, Trivy scanning, and SonarQube Community Edition analysis. A manual
deployment can proceed only after all required jobs succeed. The deployment job
uses the protected `production` GitHub Environment and a short-lived AWS OIDC
token; no AWS access keys are stored in GitHub.

See `docs/CI_CD_SETUP.md` for exact setup and evidence instructions.

## Secrets

Terraform creates the Secrets Manager container but intentionally does not put
secret values into Terraform state. Set its value after deployment using a
local JSON file that is never committed:

```json
{
  "stripe_secret_key": "REDACTED",
  "stripe_webhook_secret": "REDACTED"
}
```

```powershell
aws secretsmanager put-secret-value `
  --secret-id <terraform-output-stripe-secret-name> `
  --secret-string file://stripe-secret.json
```

The payment Lambdas receive only the secret ARN and retrieve the value using
`secretsmanager:GetSecretValue` on that exact secret.

## Disaster recovery

The recovery design uses Terraform to recreate services in `ca-central-1` and
AWS Backup to protect five DynamoDB tables and two S3 buckets in `us-east-1`.
Recovery points are copied cross-region, restored into isolated drill resources,
validated, and then promoted. Cognito users/groups and SES configuration have
separate recovery runbooks because they are not restored like DynamoDB/S3.

## Safe publishing

The root `.gitignore` excludes credentials, Terraform variables/state/plans,
dependency folders, build output, Lambda ZIPs, and local evidence. Before every
push, review `git status` and confirm no secret values are staged.

