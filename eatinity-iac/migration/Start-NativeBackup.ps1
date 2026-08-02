param(
  [string]$ConfigPath = (Join-Path $PSScriptRoot 'config.psd1'),
  [string[]]$LogicalName,
  [switch]$ConfirmNativeBackup
)

. (Join-Path $PSScriptRoot 'NativeBackup.Common.ps1')
if (-not $ConfirmNativeBackup) { throw 'Add -ConfirmNativeBackup after reviewing the AWS Backup plan and costs.' }
$context = Get-RecoveryContext -ConfigPath $ConfigPath
Assert-RecoveryAccount -Context $context
if (-not $context.Backup) { throw 'enable_enterprise_backup is false or the AWS Backup Terraform resources have not been applied.' }

$partition = if ($context.source.region -like 'us-gov-*') { 'aws-us-gov' } elseif ($context.source.region -like 'cn-*') { 'aws-cn' } else { 'aws' }
$resources = @()
foreach ($entry in $context.source.table_names.PSObject.Properties) {
  $resources += [pscustomobject]@{ LogicalName=$entry.Name; Type='DynamoDB'; Arn="arn:${partition}:dynamodb:$($context.source.region):$($context.account_id):table/$($entry.Value)" }
}
foreach ($entry in $context.source.bucket_names.PSObject.Properties) {
  $resources += [pscustomobject]@{ LogicalName=$entry.Name; Type='S3'; Arn="arn:${partition}:s3:::$($entry.Value)" }
}
if ($LogicalName) {
  $resources = @($resources | Where-Object { $_.LogicalName -in $LogicalName })
  if (-not $resources.Count) { throw "No configured source resource matches: $($LogicalName -join ', ')" }
}

$jobs = foreach ($resource in $resources) {
  Write-Host "Starting $($resource.Type) backup: $($resource.LogicalName) [$($resource.Arn)]"
  try {
    $result = Invoke-JsonCommand -Command 'aws' -Arguments @(
      'backup','start-backup-job','--backup-vault-name',$context.Backup.source_vault_name,
      '--resource-arn',$resource.Arn,'--iam-role-arn',$context.Backup.backup_role_arn,
      '--region',$context.source.region,'--output','json','--no-cli-pager'
    )
  }
  catch {
    throw "Failed to start $($resource.Type) backup '$($resource.LogicalName)' for $($resource.Arn). $($_.Exception.Message)"
  }
  $recoveryPointArn = $null
  $recoveryPointProperty = $result.PSObject.Properties['RecoveryPointArn']
  if ($recoveryPointProperty) { $recoveryPointArn = $recoveryPointProperty.Value }
  [pscustomobject]@{ LogicalName=$resource.LogicalName; ResourceType=$resource.Type; ResourceArn=$resource.Arn; BackupJobId=$result.BackupJobId; RecoveryPointArn=$recoveryPointArn }
}
$stamp = (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ')
$path = Write-JobRecord -Value $jobs -Directory $context.JobRecordRoot -Name "backup-$stamp.json"
Write-Host "Native AWS Backup jobs started. Job metadata only: $path"
