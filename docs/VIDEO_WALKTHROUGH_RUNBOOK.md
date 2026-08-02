# 15-Minute Final Presentation Runbook

All members must appear on camera, keep cameras on, share the screen for the
technical walkthrough, and have a speaking role.

## 0:00-2:00 - Solution design

- State the customer/order-management problem.
- Identify customer, administrator, and staff users.
- Explain the serverless objective, security objectives, and project scope.
- Mention S3/CloudFront rather than Amplify because that is the implemented
  hosting design for `eatinity.ca`.

## 2:00-4:00 - Architecture

- Show the final readable architecture diagram.
- Explain Route 53, ACM, CloudFront, S3, Cognito, API Gateway, Lambda, DynamoDB,
  Stripe, Secrets Manager, SES/SNS, CloudWatch, and AWS Backup.
- Trace one public product request, one authenticated request, and one checkout
  plus webhook flow.

## 4:00-7:00 - Customer workflow

- Register/confirm or use a prepared customer account.
- Sign in, browse products, add to cart, and complete Stripe test checkout.
- Show the success page, order history, profile, and address management.

## 7:00-9:00 - Administrator workflow

- Sign in with an administrator account.
- Show role protection, dashboard, menu, orders, users/staff, reports, and audit.
- Complete one realistic update and show the expected result.

## 9:00-11:30 - Disaster recovery

- State the regional-failure scenario, RPO, and RTO target.
- Show Terraform recovery code, AWS Backup configuration, recovery points,
  restored data, Cognito/SES procedure, and validation evidence.
- Confirm the recovered application is functional.

## 11:30-14:15 - CI/CD and security

- Show push/pull-request triggers and each job in the single workflow.
- Explain Trivy scanners, severity threshold, and blocking behaviour.
- Show SonarQube Community Edition and its Quality Gate.
- Show remediation evidence.
- Show the protected GitHub Environment, OIDC trust restriction, temporary AWS
  identity, and deployment/smoke-test result.

## 14:15-15:00 - Results and limitations

- Summarize successful functional, security, and recovery results.
- State honest limitations, including the SES recovery-region sandbox and DNS
  cutover not being performed during the drill.
- Identify each group member and conclude.

After recording, upload to YouTube as **Unlisted**, test the URL in an Incognito
window, and place the working link in both the submission and final report.

