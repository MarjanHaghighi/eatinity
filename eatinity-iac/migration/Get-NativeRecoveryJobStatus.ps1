param(
  [Parameter(Mandatory)][ValidateSet('Backup','Copy','Restore')][string]$JobType,
  [Parameter(Mandatory)][string]$JobId,
  [string]$ConfigPath = (Join-Path $PSScriptRoot 'config.psd1')
)

. (Join-Path $PSScriptRoot 'NativeBackup.Common.ps1')
$context = Get-RecoveryContext -ConfigPath $ConfigPath
Assert-RecoveryAccount -Context $context
$operation = switch ($JobType) { 'Backup' {'describe-backup-job'} 'Copy' {'describe-copy-job'} 'Restore' {'describe-restore-job'} }
$idFlag = switch ($JobType) { 'Backup' {'--backup-job-id'} 'Copy' {'--copy-job-id'} 'Restore' {'--restore-job-id'} }
$region = if ($JobType -eq 'Restore') { $context.destination.region } else { $context.source.region }
Invoke-JsonCommand -Command 'aws' -Arguments @('backup',$operation,$idFlag,$JobId,'--region',$region,'--output','json','--no-cli-pager')
