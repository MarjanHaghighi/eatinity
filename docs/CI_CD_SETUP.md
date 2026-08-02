# Eatinity GitHub Actions, OIDC, Trivy, and SonarQube Setup

## 1. GitHub Environment

Create a GitHub Environment named `ci` for SonarQube and a protected Environment
named `production` for deployment. Add a production approval rule when the plan
supports it. Configure these `production` variables:

| Variable | Purpose |
|---|---|
| `AWS_REGION` | Deployment region, such as `ca-central-1` |
| `AWS_DEPLOY_ROLE_ARN` | Output from the OIDC bootstrap Terraform |
| `BACKUP_OPERATOR_USER_NAME` | Existing recovery operator used by the Terraform input |
| `TF_BACKEND_BUCKET` | Separately managed encrypted Terraform state bucket |
| `TF_BACKEND_KEY` | State object key, for example `eatinity/production/terraform.tfstate` |

Configure this variable in the `ci` Environment:

| Variable | Purpose |
|---|---|
| `SONAR_HOST_URL` | Reachable URL of SonarQube Community Edition |

Add one secret to the `ci` Environment:

| Secret | Purpose |
|---|---|
| `SONAR_TOKEN` | Project analysis token created in SonarQube |

No AWS access key, AWS secret key, Stripe key, or Stripe webhook secret belongs
in GitHub.

## 2. AWS OIDC bootstrap

The identity connection is separate from the application root at
`eatinity-iac/bootstrap/github-oidc`.

1. Copy `terraform.tfvars.example` to the ignored `terraform.tfvars`.
2. Enter the exact GitHub owner, repository, and `production` environment.
3. Enter the ARN of the separately managed state bucket.
4. Run `terraform init`, `terraform validate`, and `terraform plan`.
5. Review the trust subject. It must be exactly
   `repo:OWNER/REPOSITORY:environment:production`.
6. Apply the reviewed plan with an authorized AWS administrator.
7. Copy `github_deploy_role_arn` to the GitHub Environment variable
   `AWS_DEPLOY_ROLE_ARN`.

The workflow requests `id-token: write` only in its deployment job. AWS STS
exchanges the GitHub token for a temporary role session. The trust policy checks
both the `sts.amazonaws.com` audience and the exact repository/environment
subject.

## 3. SonarQube Community Edition

1. Install or use the group's SonarQube Community Edition server.
2. Ensure the GitHub-hosted runner can reach `SONAR_HOST_URL`. If the server is
   only on a private computer, use a properly secured self-hosted runner.
3. Create the project key `eatinity`.
4. Generate a project analysis token and save it as `SONAR_TOKEN` in the `ci`
   GitHub Environment.
5. Keep `sonar-project.properties` at repository root.
6. Run the workflow and confirm the Quality Gate job succeeds.

The analysis covers React source, Python Lambda source, Terraform, and Python
tests. Generated packages, dependencies, state, and plans are excluded.

## 4. Trivy

The mandatory Trivy job scans the full repository using the vulnerability,
secret, and misconfiguration scanners. HIGH and CRITICAL findings return exit
code 1 and block deployment. The job runs on pushes, pull requests, and manual
runs.

## 5. Deployment behaviour

Normal pushes and pull requests run checks only. A deployment requires a manual
workflow dispatch with `deploy=true`. The job:

1. Waits for application/IaC checks, Trivy, and SonarQube.
2. Enters the protected `production` Environment.
3. Assumes the AWS deployment role through OIDC.
4. Builds the React application and Lambda ZIPs.
5. Initializes encrypted remote Terraform state.
6. Creates and applies the exact saved plan.
7. Synchronizes the React build to the Terraform-managed website bucket.
8. Invalidates CloudFront.
9. Smoke-tests the frontend and products API.

## 6. Evidence required for the report and video

Capture readable screenshots of:

- Push/pull-request workflow trigger and completed jobs.
- Trivy result, including what was scanned and final status.
- SonarQube dashboard and Quality Gate.
- A finding and the associated remediation commit/rerun when available.
- The deployment job's OIDC identity check, with account details safely cropped.
- Protected GitHub Environment configuration without revealing secrets.
- Restricted AWS role trust policy.
- Successful Terraform plan/apply and smoke-test steps.
