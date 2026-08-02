# Eatinity Admin Dashboard deployment readiness

> This document describes the earlier flat production-oriented configuration.
> The active production-style test root is now `environments/production` and uses the
> reusable modules under `modules/`.

This document is preparation only. No Terraform plan or apply has been run for the Admin Dashboard work.

## Local readiness completed

- Admin role navigation and protected React routes
- Menu, Orders, Users/Staff, Sales Reports, and Dashboard interfaces
- Backend authorization checks in every admin Lambda
- Authoritative DynamoDB product pricing at checkout
- Guest and authenticated checkout identity separation
- Order status workflow, ready notification, and audit records
- Cognito staff-management safeguards
- Toronto-timezone paid-sales reporting
- Lambda packages built locally
- Frontend lint/build and backend unit tests

## Must be verified before any future deployment

1. Confirm the Terraform state contains or imports every existing protected AWS resource.
2. Confirm the personal AWS identity running Terraform has the required permissions.
3. Replace placeholder Stripe values through an approved secret-management process.
4. Confirm SES domain verification and whether the account is still in the SES sandbox.
5. Review the existing Cognito user-pool tier, app client, password policy, and email delivery configuration.
6. Review the exact Terraform plan manually if planning is later authorized.
7. Add the two new Orders-table GSIs in separate safe stages if required by DynamoDB update limits.
8. Create tables and Lambdas before enabling frontend links in production.
9. Seed default categories only after `EatinityCategories` exists.
10. Add the chosen owner account to `super-admin` only after verifying its Cognito username.
11. Test with separate super-admin, admin, manager, kitchen, and customer accounts.
12. Confirm CloudWatch logs contain no secrets or unnecessary customer information.
13. Confirm newly uploaded `products/*` images are readable through the intended S3 or CloudFront delivery policy.
14. Confirm the active personal AWS account. Local state snapshots reference different account IDs and cannot identify it reliably.
15. Confirm DynamoDB point-in-time recovery and deletion protection are supported and enabled for all five tables.
16. Import existing S3 configuration resources and CloudWatch log groups before allowing Terraform to manage them.
17. Confirm the issued ACM certificate for `eatinity.ca` exists in `us-east-1` before using the custom-domain CloudFront configuration.
18. Keep `manage_public_dns = false` until the existing Route 53 aliases and CloudFront distribution are imported together.
19. Confirm the dedicated region-aware Lambda execution role remains least privilege.

## Future staged sequence — not executed

1. Back up and inspect current Terraform state and AWS resource identifiers.
2. Review formatting, tests, Lambda packages, and provider availability.
3. Produce and manually review a Terraform plan only with explicit authorization.
4. Stage table/index changes, respecting DynamoDB GSI update restrictions.
5. Stage Cognito groups, Lambdas, IAM permissions, and protected API routes.
6. Seed categories and assign the initial super-admin with explicit authorization.
7. Deploy the frontend only after backend smoke tests pass.
8. Run role-by-role and end-to-end checkout/order/email verification.

## Rollback preparation

- Preserve current Lambda ZIP packages and frontend build artifacts before deployment.
- Do not remove existing DynamoDB attributes, indexes, routes, or Cognito users during Version 1 rollout.
- Keep product deletion as archive-only and user removal as disable-only.
- Roll back frontend navigation first if an admin API is unhealthy.
