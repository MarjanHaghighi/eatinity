# Eatinity Secure E-Commerce Platform

## Final Project Technical Report

Prepared for David's final-project submission  
Application domain: `https://eatinity.ca`  
Primary platform: Amazon Web Services  
Report status: implementation-complete source with live evidence register

## 1. Solution Overview and Objectives

Eatinity is a serverless restaurant e-commerce platform that combines a public
storefront, authenticated customer services, and a role-protected administration
portal. It addresses the need for a small food business to publish a menu,
accept test-mode online payments, manage orders and staff, retain an audit trail,
and recover the service after a major AWS failure.

The objectives are to provide a usable customer journey, controlled
administrator workflows, repeatable infrastructure, automated security and
quality gates, credential-free GitHub-to-AWS deployment, operational monitoring,
and a tested cross-region disaster-recovery procedure.

### 1.1 Target users

- Guests browse products and categories without authentication.
- Registered customers manage their identity/profile, complete checkout, and
  review orders.
- Client administrators manage menu items, orders, users, reports, and audits.
- Technical operators deploy, monitor, troubleshoot, and recover the platform.

### 1.2 Main features

- Responsive React storefront and administrator interface.
- Cognito registration, confirmation, sign-in, JWT sessions, and admin groups.
- Product/category catalogue backed by DynamoDB.
- Server-validated cart pricing and Stripe test-mode checkout.
- Stripe webhook-driven order payment processing.
- Customer profiles, addresses, and order history.
- Administrator menu, order, user/staff, report, and audit workflows.
- SES/SNS notifications and CloudWatch logging.
- Terraform-based deployment and AWS Backup-based cross-region recovery.
- GitHub Actions with Trivy, SonarQube Community Edition, OIDC, and smoke tests.

### 1.3 Expected outcomes

Customers should complete a realistic order without trusting prices sent by the
browser. Administrators should operate the business only through authorized
routes. Developers should receive immediate CI feedback, and deployments should
use temporary AWS credentials. Operators should be able to rebuild the platform
and restore protected data in a separate AWS region.

### 1.4 Scope and limitations

Stripe is intentionally configured in test mode. The recovery drill uses a
regional CloudFront URL instead of changing public DNS. Cognito passwords and
MFA secrets cannot be exported; recovered users establish new passwords. SES
production access is regional, and the recovery region remains subject to its
sandbox status. Live GitHub, SonarQube, AWS-console, and video evidence must be
captured by the group because those systems require the group's accounts.

## 2. Solution Design

### 2.1 Functional requirements

- Browse products and categories.
- Register, confirm, sign in, sign out, and complete a recovery password change.
- Maintain customer profile and address information.
- Add products and quantities to a cart.
- Create a Stripe checkout session using server-authoritative product data.
- Receive and verify Stripe webhook events.
- Store and display customer orders.
- Restrict administrator functions using Cognito group claims.
- Manage products, categories, orders, staff/users, reports, and audit events.
- Send customer and operator notifications.
- Back up and restore DynamoDB/S3 data across regions.

### 2.2 Non-functional requirements

- HTTPS delivery through CloudFront and ACM.
- Scoped IAM policies and protected JWT routes, with a documented remaining
  least-privilege improvement for the shared Lambda execution role.
- No long-term AWS credentials in GitHub.
- Runtime secrets in AWS Secrets Manager, not source code or Terraform state.
- Repeatable Terraform deployment and safety checks against accidental destroy.
- DynamoDB point-in-time recovery, S3 versioning/encryption, and AWS Backup.
- Central logging with defined retention.
- Automated lint, unit tests, vulnerability scanning, static analysis, and smoke
  tests.
- A recovery target of four hours and maximum scheduled-backup data loss of 24
  hours, subject to measured drill results.

### 2.3 Major components and decisions

The frontend uses React/Vite because the interface is a static single-page
application. S3 plus CloudFront was selected instead of Amplify to retain direct
Terraform control over storage, caching, domain delivery, and recovery. API
Gateway and Lambda provide serverless APIs without persistent servers. DynamoDB
supports the access patterns and removes database-server administration.
Cognito issues JWTs and carries group information for protected routes.

Stripe payment details remain outside Eatinity; the backend creates checkout
sessions and verifies signed webhooks. AWS Secrets Manager stores the Stripe API
and webhook credentials. GitHub Actions uses OIDC so no AWS access keys need to
be saved in GitHub.

### 2.4 Assumptions

- AWS, GitHub, SonarQube, Stripe test-mode, DNS, and email identities are
  administered by authorized group members.
- The production GitHub Environment is protected and its values are configured.
- Terraform remote state is created separately, encrypted, and access controlled.
- Only sanitized screenshots and logs are inserted into the final submission.

## 3. Architecture Design

### 3.1 Application and data flow

Route 53 resolves `eatinity.ca` to CloudFront. CloudFront presents the ACM
certificate and reads the private website bucket through Origin Access Control.
The React application calls API Gateway. Public product/category routes do not
require authentication; protected routes require a Cognito JWT authorizer.
API Gateway invokes Lambda functions, which access explicitly permitted DynamoDB
tables and services.

For checkout, the Lambda reloads product names, availability, and prices from
DynamoDB, calculates tax, creates an order record, and requests a Stripe Checkout
Session. Stripe later calls the public webhook route. The webhook Lambda verifies
the signature using the Secrets Manager value, makes processing idempotent,
updates the order, and sends notifications through SNS/SES.

### 3.2 Storage and database

The website and product images use separate S3 buckets. Both support versioning
and server-side encryption in the reusable infrastructure. DynamoDB tables store
products, categories, orders, users, and administrator audit events. Production
tables enable point-in-time recovery and deletion protection.

### 3.3 Networking and security boundaries

The public internet reaches only CloudFront and API Gateway endpoints. The
website bucket is private to CloudFront OAC. Cognito validates identities and API
Gateway validates JWTs before protected integrations run. Lambda execution roles
control AWS service access. GitHub assumes a separate deployment role using an
OIDC subject restricted to the exact repository and `production` Environment.
Stripe secrets are never returned to the browser.

### 3.4 CI/CD architecture

One workflow is used because the assignment does not require separate workflow
files. Pushes and pull requests run application/IaC checks, Trivy, and SonarQube.
A manual `deploy=true` dispatch enters the protected production Environment only
after all gates pass. It assumes the OIDC role, creates an exact Terraform plan,
applies it, publishes the frontend, invalidates CloudFront, and smoke-tests the
frontend and products endpoint.

### 3.5 Disaster-recovery architecture

AWS Backup creates native recovery points for five source DynamoDB tables and
two S3 buckets in `us-east-1`, then copies them to a vault in `ca-central-1`.
Terraform rebuilds application infrastructure with region-derived names. Data is
first restored into isolated drill resources, validated, and then promoted.
Cognito user/group metadata and SES identities/templates use dedicated scripts.

**Required final insertion:** place the readable production, CI/CD/OIDC, and DR
architecture diagrams here and explain each arrow during the presentation.

## 4. Implementation Steps

### 4.1 Developer environment

Install Git, Node.js, Python 3.12, Terraform, AWS CLI, and access to the group's
GitHub and SonarQube systems. Clone the single repository. Never copy the local
`credentials`, `.tfvars`, state, plan, dependency, or generated ZIP files into a
commit.

### 4.2 Validate the frontend

```text
cd eatinity-frontend
npm ci
npm run lint
npm run build
```

The production files are generated in `eatinity-frontend/dist`.

### 4.3 Validate the backend

```text
cd eatinity-prod
python -m unittest discover -s tests -v
```

The current suite contains 18 tests covering checkout validation, order-state
rules, image uploads, audit cursors/scopes, sales reporting, super-admin
protection, webhook idempotency contracts, and Secrets Manager integration.

### 4.4 Configure Terraform

Copy the relevant `.tfvars.example` and backend example to ignored local files.
Confirm the AWS account, source and destination regions, domain settings,
deletion protection, and recovery options. Run formatting, initialization,
validation, plan, review, and apply. Apply only the exact saved plan.

### 4.5 Configure Secrets Manager

The `modules/secrets` module creates `<resource-prefix>/stripe` without a secret
version, so credentials never enter Terraform state. An authorized operator uses
`aws secretsmanager put-secret-value` with JSON keys `stripe_secret_key` and
`stripe_webhook_secret`. Payment Lambdas receive only `STRIPE_SECRET_ARN` and
retrieve the secret at runtime by calling `GetSecretValue`. The environment
variable contains only the secret ARN; it does not contain the Stripe API key or
webhook signing secret. Table names, bucket names, the Cognito pool ID, URLs,
email addresses, and SNS ARNs are operational identifiers rather than secret
values.

The current Terraform implementation assigns one shared execution role to the
application Lambdas. That role grants `secretsmanager:GetSecretValue` only for
the specific Stripe secret ARN, which prevents access to unrelated secrets, but
it also means non-payment Lambdas using the shared role technically receive the
same permission. The next least-privilege improvement is to create a dedicated
payment Lambda role for the checkout and webhook functions and remove Secrets
Manager access from the general application role. This is recorded as a
hardening improvement and does not mean that secret values are stored in source
code, GitHub, Terraform state, or Lambda environment variables.

### 4.6 Configure GitHub OIDC and Environment

Apply `eatinity-iac/bootstrap/github-oidc` separately with the exact repository
owner, repository name, `production` Environment, and state bucket. Add its role
ARN and the documented non-secret variables to the production Environment. Put
the Sonar host and project token in a separate `ci` Environment. Do not add AWS
or Stripe keys.

### 4.7 Configure SonarQube Community Edition

Create the `eatinity` project, generate a project token, and ensure the GitHub
runner can reach the server. Store the host URL and token in the `ci` GitHub
Environment. `sonar-project.properties` scopes analysis to the
React, Python, Terraform, and test sources. The workflow fails when the Quality
Gate fails.

### 4.8 Deployment validation

After apply, synchronize the React build to S3, invalidate CloudFront, request
the frontend URL, and request the products endpoint. Validate Cognito, checkout,
webhook, notifications, logs, and administrator routes using the walkthroughs.

## 5. Relevant Code and Configuration

### 5.1 Server-authoritative checkout

The checkout Lambda accepts only product IDs and quantities from the browser,
then reloads authoritative name, price, availability, and archive state from
DynamoDB. This prevents a customer from changing a price in browser data.

### 5.2 Secrets retrieval

Both payment Lambdas load the JSON secret through `boto3` and cache it for the
warm runtime. The checkout uses the API key; the webhook uses both the API key
and webhook signing secret.

### 5.3 Protected deployment

The workflow grants `id-token: write` only to the production deployment job. The
AWS trust policy requires the `sts.amazonaws.com` audience and the exact GitHub
repository/environment subject. All validation and security jobs must pass first.

### 5.4 Security scanning

Trivy scans vulnerabilities, dependencies, embedded secrets, and Terraform/AWS
misconfiguration. HIGH or CRITICAL results return a non-zero exit code.
SonarQube analyzes application and IaC source and enforces its Quality Gate.

## 6. End-to-End User Experience Walkthroughs

### 6.1 Client administrator

1. Open the administrator sign-in page and authenticate with an authorized
   Cognito group member.
2. Confirm the dashboard loads and that an ordinary customer cannot enter it.
3. Create or update a product/category and confirm it appears in the storefront.
4. Open an order, follow an allowed status transition, and confirm an invalid
   transition is rejected.
5. Review users/staff and confirm super-admin self-protection.
6. Open sales reports and verify totals for a selected period.
7. Open the audit log and confirm the performed administrator action appears.
8. Sign out and confirm protected routes are no longer accessible.

Insert screenshots, expected results, actual results, and timestamps for each
major step.

### 6.2 End customer

1. Register and confirm an account, or use a prepared confirmed test customer.
2. Sign in and browse categories/products.
3. Add products and quantities to the cart.
4. Enter customer/delivery information and create checkout.
5. Complete a Stripe test-mode payment without displaying card details in the
   report or video.
6. Confirm the success page and order record.
7. Review order history, profile, payment-method presentation, and addresses.
8. Sign out and confirm authenticated pages are protected.

Insert screenshots and expected/actual results. Demonstrate a connected workflow,
not disconnected pages.

## 7. Disaster Recovery Design and Implementation

The selected scenario is loss of the primary AWS region. The target RPO is 24
hours under the daily schedule and the target operator-led RTO is four hours.
Source recovery points are retained for 35 days and destination copies for 90
days. Restore targets are isolated until validation succeeds.

The runbook verifies prerequisites, starts native backups, monitors jobs, copies
recovery points, restores data, validates counts/schema/indexes, promotes data,
synchronizes Cognito metadata, validates SES, deploys the regional frontend, and
runs application tests. Existing evidence records show seven copy records, five
core DynamoDB dataset validations, Cognito synchronization, and SES template
synchronization. These files support but do not replace readable screenshots and
the recorded recovery demonstration.

Limitations include Cognito password/MFA re-establishment, SES regional sandbox
status, no public DNS cutover during the drill, and the need to measure actual
stage timestamps for a defensible achieved RTO.

## 8. Automated Security and Code-Quality Testing

The combined workflow triggers on `main` pushes, `main` pull requests, and manual
dispatch. Trivy scans the entire repository for dependency vulnerabilities,
secrets, and misconfiguration. HIGH/CRITICAL findings fail the job and prevent
deployment. SonarQube Community Edition scans React, Python, Terraform, and tests;
the Quality Gate is enforced before deployment.

The final submission must include actual GitHub and SonarQube results, at least
one identified issue where available, the remediation commit, and a passing
rerun. Configuration alone is not evidence of execution.

## 9. GitHub Repository and CI/CD Security

The project uses one repository and documents its existing functional areas in
the root README. Application configuration remains in the repository, while the
AWS GitHub identity setup is isolated in `eatinity-iac/bootstrap/github-oidc`.
The trust policy is restricted to the exact repository and protected Environment.
The service-limited deployment policy separates broad read operations needed by
Terraform from the explicit mutation actions used by Eatinity and restricts IAM
resources to the Eatinity name prefix.

GitHub stores non-sensitive deployment identifiers in the protected `production`
Environment and the Sonar host/token in the separate `ci` Environment. AWS credentials are never
stored; OIDC creates a temporary STS session. Stripe credentials remain in AWS
Secrets Manager and are fetched at runtime through an IAM policy restricted to
the specific Stripe secret ARN. The current shared execution role should be
split so only checkout and webhook retain that permission. Logs, source,
screenshots, and video must not reveal secret values.

## 10. Testing Results

Local validation on August 1, 2026 produced these verified results:

| Test | Result |
|---|---|
| Frontend ESLint | PASS |
| Frontend Vite production build | PASS; 117 modules transformed |
| Python backend unit tests | PASS; 18 tests |
| Changed Terraform file formatting | PASS |
| Production Terraform validation | PASS; local ignored `.tfvars` warns about two obsolete Stripe inputs |
| GitHub OIDC bootstrap Terraform validation | PASS |

The two production validation warnings come from obsolete Stripe values that
remain only in the existing ignored local `terraform.tfvars`; the configuration
no longer declares or consumes them. Remove those two local lines after safely
placing the values in Secrets Manager. The GitHub Actions runner must repeat
Terraform validation and its result must be captured. Live Trivy, SonarQube,
OIDC, AWS deployment, smoke-test, and user-flow results must likewise be inserted
from the group's systems.

## 11. Operations and Troubleshooting

CloudWatch log groups retain Lambda and API Gateway activity for the configured
period. Operators correlate API request failures with Lambda logs, inspect
DynamoDB and Stripe test events, verify SES/SNS status, and review GitHub Actions
logs without printing secrets. Recovery operators follow the migration README
and preserve job records as evidence.

Common checks are frontend/API reachability, Cognito issuer/audience alignment,
CORS origins, Lambda environment identifiers, Secrets Manager permissions,
Stripe webhook signature validity, DynamoDB table/index availability, and
CloudFront invalidation completion.

## 12. Evidence and Submission Checklist

Use `docs/FINAL_EVIDENCE_REGISTER.md` as the authoritative capture list. Before
submission, confirm:

- The repository and all submitted links are accessible.
- The full report contains readable diagrams and screenshots.
- Customer, administrator, DR, Trivy, SonarQube, OIDC, and deployment results are
  demonstrated rather than merely described.
- Security findings and remediation evidence are included.
- No secret values or private credentials appear anywhere.
- Every group member participates on camera and speaks.
- The YouTube video is Unlisted and works in an Incognito window.

## 13. Conclusion

Eatinity combines a functional serverless commerce application with repeatable
AWS infrastructure, protected authentication and administration, server-side
payment validation, monitoring, automated security gates, short-lived deployment
credentials, and cross-region recovery automation. The repository now contains
the configuration and documentation required to execute the final CI/CD and
evidence collection. The remaining submission work is inherently live: configure
the group's GitHub/SonarQube/AWS values, execute the workflows and user/DR tests,
insert genuine evidence, record the group presentation, and verify every link.
