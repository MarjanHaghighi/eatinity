# GitHub OIDC bootstrap

This Terraform root is intentionally separate from the recoverable Eatinity
application stack. Run it once with an authorized administrator to establish
the AWS identity connection used by GitHub Actions.

1. Copy `terraform.tfvars.example` to the uncommitted `terraform.tfvars`.
2. Set the exact GitHub owner, repository, and protected environment.
3. Run `terraform init`, `terraform validate`, `terraform plan`, and apply the
   reviewed plan.
4. Add the `github_deploy_role_arn` output to the GitHub `production`
   Environment as the variable `AWS_DEPLOY_ROLE_ARN`.

The trust policy accepts only an OIDC token for the exact repository and
environment. No AWS access key is stored in GitHub. The deployment policy is
limited to the AWS service actions used by Eatinity, an Eatinity IAM name
prefix, and the specified remote-state bucket.

