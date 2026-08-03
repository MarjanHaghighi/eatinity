# eatinity Project Structure

This document presents the main folders and important files in the eatinity
repository. Generated dependencies, build output, caches, Terraform state,
saved plans, Lambda ZIP packages, and local recovery working files are omitted.

**Last verified:** August 2, 2026, after the final repository cleanup.

```text
Eatinity/
|-- .github/
|   `-- workflows/
|       |-- final-project-ci-cd.yml       # Tests, Terraform, Trivy and SonarQube pipeline
|       `-- oidc-verification.yml         # GitHub-to-AWS OIDC verification
|
|-- docs/
|   |-- architecture/
|   |   |-- Architecture.png
|   |   |-- CICD-OIDC-Architecture.png
|   |   `-- DisasterRecovery-Architecture.png
|   |-- evidence/
|   |   `-- sonarqube/                    # SonarQube evidence screenshots
|   |-- guides/
|   |   |-- ADMIN_USER_GUIDE.md
|   |   |-- LOCAL_ADMIN_HANDOFF.md
|   |   `-- LOCAL_VERIFICATION_GUIDE.md
|   |-- CI_CD_SETUP.md
|   |-- DISASTER_RECOVERY_RUNBOOK.md
|   |-- EATINITY_FINAL_PROJECT_REPORT.md
|   |-- FINAL_EVIDENCE_REGISTER.md
|   |-- PROJECT_STRUCTURE.md
|   |-- SECURITY_EXCEPTIONS.md
|   `-- VIDEO_WALKTHROUGH_RUNBOOK.md
|
|-- eatinity-frontend/                    # React/Vite customer and administrator website
|   |-- public/
|   |   `-- runtime-config.js
|   |-- src/
|   |   |-- admin/                        # Admin API, components, pages and styles
|   |   |-- api/                          # Customer-facing API clients
|   |   |-- assets/                       # Logo and website images
|   |   |-- auth/                         # Cognito authentication logic
|   |   |-- components/                   # Shared interface components
|   |   |-- pages/                        # Customer pages and checkout flow
|   |   |-- App.jsx
|   |   |-- config.js
|   |   `-- main.jsx
|   |-- index.html
|   |-- package.json
|   |-- README.md
|   `-- vite.config.js
|
|-- eatinity-iac/                         # Modular Terraform and recovery automation
|   |-- bootstrap/
|   |   `-- github-oidc/                  # GitHub OIDC provider and verification role
|   |-- environments/
|   |   `-- production/                   # Region-selectable Terraform root module
|   |       |-- main.tf
|   |       |-- variables.tf
|   |       |-- outputs.tf
|   |       |-- locals.tf
|   |       |-- checks.tf
|   |       `-- versions.tf
|   |-- migration/                        # Backup, copy, restore and recovery jobs
|   |   |-- Start-NativeBackup.ps1
|   |   |-- Start-NativeCopy.ps1
|   |   |-- Start-NativeRestore.ps1
|   |   |-- Get-NativeRecoveryJobStatus.ps1
|   |   |-- Copy-RestoredDynamoData.ps1
|   |   |-- Sync-CognitoRecoveryUsers.ps1
|   |   |-- Sync-SesRecoveryTemplates.ps1
|   |   |-- Test-RegionalPaymentRecovery.ps1
|   |   `-- Deploy-RegionalFrontend.ps1
|   |-- modules/
|   |   |-- application/                  # API Gateway, Lambda, IAM and monitoring
|   |   |-- database/                     # DynamoDB tables
|   |   |-- delivery/                     # CloudFront delivery
|   |   |-- identity/                     # Cognito authentication
|   |   |-- operations/                   # CloudWatch and notifications
|   |   |-- recovery_backup/              # AWS Backup and cross-Region recovery
|   |   |-- secrets/                      # Secrets Manager containers
|   |   `-- storage/                      # S3 website and product-image storage
|   |-- DEPLOYMENT_READINESS.md
|   |-- IMPORT_GUIDE.md
|   `-- README.md
|
|-- eatinity-prod/                        # Application Lambda source and legacy stack files
|   |-- lambda/
|   |   |-- stripe_requirements.txt       # Pinned payment Lambda dependency
|   |   |-- admin_audit/
|   |   |-- admin_menu/
|   |   |-- admin_orders/
|   |   |-- admin_users/
|   |   |-- products/
|   |   |-- sales_reports/
|   |   |-- stripe_checkout/
|   |   |-- stripe_webhook/
|   |   `-- user_profile/
|   |-- tests/
|   |   `-- test_admin_logic.py
|   |-- scripts/
|   |   `-- build_lambda_packages.sh      # Reproducible Linux Lambda packaging
|   |-- main.tf
|   |-- variables.tf
|   `-- outputs.tf
|
|-- .gitignore                            # Excludes secrets and generated files
|-- .trivyignore                          # Reviewed Trivy exceptions
|-- bootstrap.sh                          # Regional deployment and DR entry point
|-- sonar-project.properties              # SonarQube analysis configuration
`-- README.md
```

## Folder responsibilities

- `.github/workflows` contains the CI/CD, security scanning, SonarQube, and AWS
  OIDC verification workflows.
- `eatinity-frontend` contains the customer and administrator web application.
- `eatinity-prod/lambda` contains the Python Lambda handlers used by the APIs.
- `eatinity-iac` contains the reusable Terraform modules, production environment,
  OIDC bootstrap configuration, and disaster-recovery job scripts.
- `docs` contains architecture diagrams, evidence, the final report, operational
  guidance, administrator guides, and presentation material.
- `bootstrap.sh` is the guarded entry point documented by the disaster-recovery
  runbook. It does not apply Terraform automatically.
- The repository root intentionally contains only the five main project folders
  and the essential Git, security, bootstrap, SonarQube, and README files shown
  above.

## Intentionally omitted

The structure excludes `.git`, `node_modules`, `.terraform`, build and rendering
directories, Python caches, Terraform state and plan files, packaged ZIP files,
local `.eatinity-recovery` configuration, and credentials or secret values.
