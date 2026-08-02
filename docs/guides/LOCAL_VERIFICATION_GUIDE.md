# Eatinity Admin Dashboard Local Verification

These commands are read-only with respect to AWS. Run them from PowerShell in `C:\Marjan\Eatinity`.

## Backend tests

```powershell
Set-Location C:\Marjan\Eatinity\eatinity-prod
python -m unittest discover -s tests -v
```

Expected current result: 18 tests pass.

## Frontend lint and production build

```powershell
Set-Location C:\Marjan\Eatinity\eatinity-frontend
npm run lint
npm run build
```

Both commands should exit successfully. The build is written to `eatinity-frontend/dist` locally.

## Terraform formatting and configuration references

```powershell
Set-Location C:\Marjan\Eatinity\eatinity-iac
terraform fmt -check
terraform providers
```

These commands do not create a plan and do not change AWS.

Do not run `terraform plan` or `terraform apply` unless the owner gives separate explicit authorization and the readiness checklist has been completed.

## Lambda package handlers

Each Terraform Lambda ZIP must contain its handler at the ZIP root:

| ZIP | Handler file |
|---|---|
| `get_products.zip` | `get_products.py` |
| `admin_menu.zip` | `admin_menu.py` |
| `admin_orders.zip` | `admin_orders.py` |
| `admin_users.zip` | `admin_users.py` |
| `admin_audit.zip` | `admin_audit.py` |
| `sales_reports.zip` | `sales_reports.py` |
| `stripe_checkout.zip` | `create_checkout_session.py` |
| `stripe_webhook.zip` | `process_stripe_webhook.py` |
| `user_profile.zip` | `user_profile.py` |

## Local limitations

Local tests mock AWS clients. They do not prove:

- IAM permissions in the AWS Academy account
- Terraform state/import correctness
- Cognito email and group behavior
- SES/SNS delivery
- Stripe webhook delivery
- DynamoDB index creation
- S3 object delivery permissions
- API Gateway CORS in production

Those items require a separately authorized deployed-environment verification.
