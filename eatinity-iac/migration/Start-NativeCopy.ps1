param(
  [Parameter(Mandatory)][string]$RecoveryPointArn,
  [string]$ConfigPath = (Join-Path $PSScriptRoot 'config.psd1'),
  [switch]$ConfirmCrossRegionCopy
)

. (Join-Path $PSScriptRoot 'NativeBackup.Common.ps1')
if (-not $ConfirmCrossRegionCopy) { throw 'Add -ConfirmCrossRegionCopy after the source backup job is COMPLETED.' }
$context = Get-RecoveryContext -ConfigPath $ConfigPath
Assert-RecoveryAccount -Context $context
if (-not $context.Backup) { throw 'AWS Backup Terraform outputs are unavailable.' }
$result = Invoke-JsonCommand -Command 'aws' -Arguments @(
  'backup','start-copy-job','--recovery-point-arn',$RecoveryPointArn,
  '--source-backup-vault-name',$context.Backup.source_vault_name,
  '--destination-backup-vault-arn',$context.Backup.destination_vault_arn,
  '--iam-role-arn',$context.Backup.backup_role_arn,
  '--region',$context.source.region,'--output','json','--no-cli-pager'
)
$path = Write-JobRecord -Value ([pscustomobject]@{CopyJobId=$result.CopyJobId; SourceRecoveryPointArn=$RecoveryPointArn; DestinationVaultArn=$context.Backup.destination_vault_arn}) -Directory $context.JobRecordRoot -Name "copy-$($result.CopyJobId).json"
Write-Host "Cross-region copy job started: $($result.CopyJobId). Job metadata only: $path"
