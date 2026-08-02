# Final Evidence Register

Replace every `PENDING LIVE CAPTURE` entry with a real screenshot or link before
submission. Do not fabricate results and do not expose credentials.

| ID | Requirement | Evidence source | Status |
|---|---|---|---|
| E01 | GitHub repository and documented structure | GitHub repository + root README | PENDING LIVE CAPTURE |
| E02 | Push and pull-request workflow triggers | GitHub Actions workflow page | PENDING LIVE CAPTURE |
| E03 | Frontend lint and build | GitHub Actions application checks | PENDING LIVE CAPTURE |
| E04 | Backend automated tests | GitHub Actions: 18 unit tests | PENDING LIVE CAPTURE |
| E05 | Terraform validation | GitHub Actions application/IaC checks | PENDING LIVE CAPTURE |
| E06 | Trivy source/dependency/secret/IaC scan | GitHub Actions Trivy job | PENDING LIVE CAPTURE |
| E07 | Trivy failure behaviour or finding | Failed job/log or controlled evidence | PENDING LIVE CAPTURE |
| E08 | Trivy remediation and passing rerun | Commit and successful job | PENDING LIVE CAPTURE |
| E09 | SonarQube Community Edition dashboard | SonarQube project | PENDING LIVE CAPTURE |
| E10 | SonarQube Quality Gate | SonarQube + GitHub Actions | PENDING LIVE CAPTURE |
| E11 | SonarQube finding/remediation | Issue detail + commit + rerun | PENDING LIVE CAPTURE |
| E12 | GitHub Environment | Repository Settings > Environments | PENDING LIVE CAPTURE |
| E13 | OIDC trust policy restrictions | AWS IAM role trust relationship | PENDING LIVE CAPTURE |
| E14 | OIDC temporary identity | `aws sts get-caller-identity` step | PENDING LIVE CAPTURE |
| E15 | Least-privilege deployment policy | AWS IAM policy + Terraform source | PENDING LIVE CAPTURE |
| E16 | Secrets Manager secret metadata | AWS console; never reveal value | PENDING LIVE CAPTURE |
| E17 | Successful frontend deployment | S3/CloudFront job + eatinity.ca | PENDING LIVE CAPTURE |
| E18 | Successful API smoke test | GitHub Actions smoke-test step | PENDING LIVE CAPTURE |
| E19 | Customer registration/sign-in | Application walkthrough | PENDING LIVE CAPTURE |
| E20 | Customer browsing/cart/checkout | Application + Stripe test mode | PENDING LIVE CAPTURE |
| E21 | Customer order history/profile | Application walkthrough | PENDING LIVE CAPTURE |
| E22 | Administrator authorization | Admin UI + unauthorized-access test | PENDING LIVE CAPTURE |
| E23 | Menu and product management | Admin UI | PENDING LIVE CAPTURE |
| E24 | Order workflow | Admin UI | PENDING LIVE CAPTURE |
| E25 | Users/reports/audit | Admin UI | PENDING LIVE CAPTURE |
| E26 | CloudWatch logs and alarms | AWS console | PENDING LIVE CAPTURE |
| E27 | DR Terraform plan/apply | Existing DR evidence set | PENDING INSERTION |
| E28 | Seven cross-region recovery points | AWS Backup / existing job records | PENDING INSERTION |
| E29 | DynamoDB restore/count validation | Existing job records and console | PENDING INSERTION |
| E30 | S3 recovery | AWS Backup / S3 console | PENDING INSERTION |
| E31 | Cognito recovery validation | Existing Cognito job record | PENDING INSERTION |
| E32 | SES/DKIM validation | Existing SES job record | PENDING INSERTION |
| E33 | Recovered application tests | Recovery CloudFront URL | PENDING INSERTION |
| E34 | Final no-change plan | Terraform terminal | PENDING LIVE CAPTURE |
| E35 | Unlisted YouTube presentation | Incognito-tested YouTube link | PENDING GROUP RECORDING |

