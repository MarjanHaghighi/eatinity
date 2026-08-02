param(
  [Parameter(Mandatory)][string]$RecoveryPointArn,
  [Parameter(Mandatory)][ValidateSet('DynamoDB','S3')][string]$ResourceType,
  [Parameter(Mandatory)][string]$RestoreTargetName,
  [string]$ConfigPath = (Join-Path $PSScriptRoot 'config.psd1'),
  [switch]$ConfirmNativeRestore
)

. (Join-Path $PSScriptRoot 'NativeBackup.Common.ps1')
if (-not $ConfirmNativeRestore) { throw 'Add -ConfirmNativeRestore after verifying the copied recovery point and target name.' }
$context = Get-RecoveryContext -ConfigPath $ConfigPath
Assert-RecoveryAccount -Context $context
if (-not $context.Backup) { throw 'AWS Backup Terraform outputs are unavailable.' }

$metadataResult = Invoke-JsonCommand -Command 'aws' -Arguments @('backup','get-recovery-point-restore-metadata','--backup-vault-name',$context.Backup.destination_vault_name,'--recovery-point-arn',$RecoveryPointArn,'--region',$context.destination.region,'--output','json','--no-cli-pager')
$metadata = @{}
foreach ($property in $metadataResult.RestoreMetadata.PSObject.Properties) { $metadata[$property.Name] = [string]$property.Value }
if ($ResourceType -eq 'DynamoDB') { $metadata.targetTableName = $RestoreTargetName }
if ($ResourceType -eq 'S3') {
  $metadata.DestinationBucketName = $RestoreTargetName
  $metadata.EncryptionType = 'SSE-S3'
  $metadata.RestoreACLs = 'false'
}
$metadataFile = Join-Path $env:TEMP "eatinity-restore-$([guid]::NewGuid().ToString('N')).json"
try {
  [IO.File]::WriteAllText($metadataFile, ($metadata | ConvertTo-Json -Compress), [Text.UTF8Encoding]::new($false))
  $result = Invoke-JsonCommand -Command 'aws' -Arguments @('backup','start-restore-job','--recovery-point-arn',$RecoveryPointArn,'--metadata',"file://$metadataFile",'--iam-role-arn',$context.Backup.backup_role_arn,'--resource-type',$ResourceType,'--region',$context.destination.region,'--output','json','--no-cli-pager')
} finally { Remove-Item -LiteralPath $metadataFile -Force -ErrorAction SilentlyContinue }
$path = Write-JobRecord -Value ([pscustomobject]@{RestoreJobId=$result.RestoreJobId; ResourceType=$ResourceType; Target=$RestoreTargetName; RecoveryPointArn=$RecoveryPointArn}) -Directory $context.JobRecordRoot -Name "restore-$($result.RestoreJobId).json"
Write-Host "Native restore job started: $($result.RestoreJobId). Job metadata only: $path"
