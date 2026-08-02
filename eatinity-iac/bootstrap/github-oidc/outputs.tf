output "github_deploy_role_arn" { value = aws_iam_role.github_deploy.arn }
output "restricted_subject" {
  value = "repo:${var.github_owner}/${var.github_repository}:environment:${var.github_environment}"
}

