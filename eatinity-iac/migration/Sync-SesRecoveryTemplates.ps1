param(
  [string]$ConfigPath = (Join-Path $PSScriptRoot 'config.psd1'),
  [switch]$ConfirmDestinationTemplateWrite
)

. (Join-Path $PSScriptRoot 'NativeBackup.Common.ps1')
if (-not $ConfirmDestinationTemplateWrite) {
  throw 'Add -ConfirmDestinationTemplateWrite to create or update templates only in the recovery region.'
}

$context = Get-RecoveryContext -ConfigPath $ConfigPath
Assert-RecoveryAccount -Context $context
$templates = Invoke-JsonCommand -Command 'aws' -Arguments @(
  'ses','list-templates','--region',$context.source.region,'--output','json','--no-cli-pager'
)

$created = 0; $updated = 0
foreach ($metadata in @($templates.TemplatesMetadata)) {
  $source = Invoke-JsonCommand -Command 'aws' -Arguments @(
    'ses','get-template','--template-name',$metadata.Name,
    '--region',$context.source.region,'--output','json','--no-cli-pager'
  )
  $templateFile = Join-Path $env:TEMP "eatinity-ses-template-$([guid]::NewGuid().ToString('N')).json"
  try {
    [IO.File]::WriteAllText($templateFile, ($source.Template | ConvertTo-Json -Depth 10), [Text.UTF8Encoding]::new($false))
    $exists = $true
    try {
      Invoke-JsonCommand -Command 'aws' -Arguments @(
        'ses','get-template','--template-name',$metadata.Name,
        '--region',$context.destination.region,'--output','json','--no-cli-pager'
      ) | Out-Null
    } catch {
      if ($_.Exception.Message -match 'TemplateDoesNotExist') { $exists = $false } else { throw }
    }
    $operation = if ($exists) { 'update-template' } else { 'create-template' }
    Invoke-JsonCommand -Command 'aws' -Arguments @(
      'ses',$operation,'--template',"file://$templateFile",
      '--region',$context.destination.region,'--output','json','--no-cli-pager'
    ) | Out-Null
    if ($exists) { $updated++ } else { $created++ }
  }
  finally {
    Remove-Item -LiteralPath $templateFile -Force -ErrorAction SilentlyContinue
  }
}

$result = [pscustomobject]@{
  SourceTemplates = @($templates.TemplatesMetadata).Count
  CreatedTemplates = $created
  UpdatedTemplates = $updated
  SourceRegion = $context.source.region
  DestinationRegion = $context.destination.region
}
$stamp = (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ')
$path = Write-JobRecord -Value $result -Directory $context.JobRecordRoot -Name "ses-template-sync-$stamp.json"
$result | Format-List
Write-Host "SES template synchronization complete. Evidence: $path"
