param([string]$ConfigPath = (Join-Path $PSScriptRoot 'config.psd1'))

. (Join-Path $PSScriptRoot 'NativeBackup.Common.ps1')
$context = Get-RecoveryContext -ConfigPath $ConfigPath
Assert-RecoveryAccount -Context $context

$failures = @()
foreach ($entry in $context.source.table_names.PSObject.Properties) {
  try {
    Invoke-JsonCommand -Command 'aws' -Arguments @('dynamodb','describe-table','--table-name',$entry.Value,'--region',$context.source.region,'--output','json','--no-cli-pager') | Out-Null
    Write-Host "PASS DynamoDB $($entry.Value)"
  } catch { $failures += "DynamoDB:$($entry.Value)"; Write-Host "FAIL DynamoDB $($entry.Value)" }
}
foreach ($entry in $context.source.bucket_names.PSObject.Properties) {
  try {
    $versioning = Invoke-JsonCommand -Command 'aws' -Arguments @('s3api','get-bucket-versioning','--bucket',$entry.Value,'--region',$context.source.region,'--output','json','--no-cli-pager')
    if ($versioning.Status -ne 'Enabled') { throw 'Versioning is not enabled.' }
    Write-Host "PASS S3 versioning $($entry.Value)"
  } catch { $failures += "S3:$($entry.Value)"; Write-Host "FAIL S3 versioning $($entry.Value)" }
}
$settings = Invoke-JsonCommand -Command 'aws' -Arguments @('backup','describe-region-settings','--region',$context.source.region,'--output','json','--no-cli-pager')
foreach ($type in @('DynamoDB','S3')) {
  $enabled = $settings.ResourceTypeOptInPreference.$type
  if ($enabled -eq $false) { $failures += "AWSBackup:$type"; Write-Host "FAIL AWS Backup opt-in $type" }
  else { Write-Host "PASS AWS Backup opt-in $type" }
}
if ($failures.Count) { throw "Prerequisites failed: $($failures -join ', ')" }
Write-Host 'AWS-native backup prerequisites passed.'
