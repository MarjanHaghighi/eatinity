output "source_vault_name" { value = aws_backup_vault.source.name }
output "destination_vault_name" { value = aws_backup_vault.destination.name }
output "destination_vault_arn" { value = aws_backup_vault.destination.arn }
output "backup_plan_id" { value = aws_backup_plan.cross_region.id }
output "backup_role_arn" { value = aws_iam_role.backup.arn }
output "operator_policy_arn" { value = aws_iam_policy.operator.arn }
