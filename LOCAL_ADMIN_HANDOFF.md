# Eatinity Admin Dashboard — local handoff

## Status

Version 1 is implemented and verified locally. No Terraform plan/apply, AWS CLI mutation, deployment, DynamoDB seed, Cognito group assignment, or live API test was performed.

## Implemented modules

- Role-aware Admin shell and navigation
- Menu products and categories
- Order listing, details, workflows, ready email, and history
- Customer and staff listing
- Cognito staff invitations, groups, enable/disable, and password resets
- Today, daily, weekly, monthly, and custom sales reports
- Dashboard summaries, recent orders, and best sellers
- Audit records for order, menu, category, and staff changes
- Super-admin Audit Log page with filtering, pagination, and before/after values
- Protected direct product-image uploads through S3 presigned posts
- Guest and authenticated checkout separation
- DynamoDB-authoritative checkout prices

## Roles

| Role | Dashboard | Orders | Menu | Users/Staff | Reports | Audit Log |
|---|---:|---:|---:|---:|---:|---:|
| super-admin | Yes | Full | Full | Full | Yes | Yes |
| admin | Yes | Full | Full | View | Yes | No |
| manager | Yes | Full | Full | No | Yes | No |
| kitchen | Redirect to Orders | Kitchen transitions | No | No | No | No |
| customer | No | Own orders only | Storefront only | No | No | No |

## Local verification

- `python -m unittest discover -s tests -v`: 18 tests passed
- `npm run lint`: passed
- `npm run build`: passed
- `terraform fmt -check`: passed
- `terraform providers`: configuration references parsed
- Nine Lambda ZIP packages contain their expected handlers

## Important integration protections

- Browser-submitted prices and product names are ignored at checkout.
- Guest checkout cannot claim a Cognito user ID.
- Authenticated checkout uses the verified Cognito `sub` claim.
- Stripe webhook retries preserve the current kitchen/order status.
- Stripe webhook retries skip notification channels that already succeeded.
- Product deletion is archive-only; staff/customer removal is disable-only.
- Final and current super-admin safeguards exist in both UI and backend.

## Requires future AWS verification

- Existing Terraform state/import alignment
- `LabRole` permissions, especially Cognito admin operations
- Cognito group creation and initial super-admin assignment
- DynamoDB table and staged GSI creation
- SES verification/sandbox behavior and real email delivery
- SNS subscription behavior
- Stripe webhook and Checkout integration
- Category bootstrap
- Role-by-role browser tests against deployed APIs
- CloudWatch log and alarm review

See `eatinity-iac/DEPLOYMENT_READINESS.md` for the future staged sequence. That sequence has not been executed.

## Guides

- `ADMIN_USER_GUIDE.md`: staff roles and operational workflows
- `LOCAL_VERIFICATION_GUIDE.md`: repeatable local checks and limitations
- `eatinity-iac/DEPLOYMENT_READINESS.md`: future deployment prerequisites and sequence
