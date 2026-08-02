# Security Scan Exceptions

The CI security gate fails on all unreviewed high and critical Trivy findings.
The following narrow exceptions document findings that are not exploitable or
are accepted design decisions. Every exception has an expiry date so it must be
reviewed rather than silently remaining forever.

| Finding | Scope | Decision | Expiry |
|---|---|---|---|
| GHSA-qwww-vcr4-c8h2 | `eatinity-frontend/package-lock.json` | Eatinity is a client-side Vite SPA and does not use the affected unstable React Router RSC server APIs. No compatible `react-router-dom` 8.3.0 package is published. | 2026-09-30 |
| AWS-0132 | Active website and image buckets | Static public assets use S3-managed AES-256 encryption. A customer-managed key would add cost but would not reduce exposure of public content. | 2026-12-31 |
| AWS-0087 / AWS-0093 | Active product-image bucket | Product images intentionally have stable public read URLs; ACLs remain blocked, write access is IAM-controlled, and no customer data is stored. | 2026-12-31 |
| AWS-0011 / S3 public-access checks | Files under `eatinity-prod/*.tf` | These files are retained historical Terraform and are not the deployment root. The active modular CloudFront configuration requires a WAF ARN. | 2026-12-31 |

The denial-of-service issue CVE-2026-55685 was remediated by upgrading
`react-router-dom` and `react-router` from 7.17.0 to 7.18.2. SNS topics now use
AWS-managed KMS encryption, and the active CloudFront module accepts and attaches
the existing us-east-1 WAFv2 web ACL ARN.
