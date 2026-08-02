param([string]$ConfigPath = (Join-Path $PSScriptRoot 'config.psd1'))

. (Join-Path $PSScriptRoot 'NativeBackup.Common.ps1')
$context = Get-RecoveryContext -ConfigPath $ConfigPath
Assert-RecoveryAccount -Context $context

function Get-CognitoAttributeValue {
  param([object[]]$Attributes, [string]$Name)
  $attribute = @($Attributes | Where-Object { $_.Name -eq $Name } | Select-Object -First 1)
  if (-not $attribute.Count) { return $null }
  return [string]$attribute[0].Value
}

$source = Invoke-JsonCommand -Command 'aws' -Arguments @(
  'cognito-idp','list-users','--user-pool-id',$context.source.cognito_user_pool_id,
  '--region',$context.source.region,'--output','json','--no-cli-pager'
)
$destination = Invoke-JsonCommand -Command 'aws' -Arguments @(
  'cognito-idp','list-users','--user-pool-id',$context.destination.cognito_user_pool_id,
  '--region',$context.destination.region,'--output','json','--no-cli-pager'
)

$sourceMappings = @($source.Users | ForEach-Object {
  $destinationUsername = if ([string]$_.Username -match '^[^@\s]+@[^@\s]+\.[^@\s]+$') {
    [string]$_.Username
  } else {
    Get-CognitoAttributeValue -Attributes @($_.Attributes) -Name 'email'
  }
  [pscustomobject]@{ SourceUsername = [string]$_.Username; DestinationUsername = $destinationUsername }
})
$sourceNames = @($sourceMappings | ForEach-Object DestinationUsername)
$destinationMappings = @($destination.Users | ForEach-Object {
  [pscustomobject]@{
    Username = [string]$_.Username
    Email    = Get-CognitoAttributeValue -Attributes @($_.Attributes) -Name 'email'
  }
})
$destinationEmails = @($destinationMappings | ForEach-Object Email)
$missing = @($sourceNames | Where-Object { $_ -notin $destinationEmails })

$sourceMembershipCount = 0; $destinationMembershipCount = 0
foreach ($mapping in $sourceMappings) {
  $sourceGroups = Invoke-JsonCommand -Command 'aws' -Arguments @(
    'cognito-idp','admin-list-groups-for-user','--user-pool-id',$context.source.cognito_user_pool_id,
    '--username',$mapping.SourceUsername,'--region',$context.source.region,'--output','json','--no-cli-pager'
  )
  $sourceMembershipCount += @($sourceGroups.Groups).Count
  $destinationMatch = @($destinationMappings | Where-Object {
    $_.Email -eq $mapping.DestinationUsername
  } | Select-Object -First 1)
  if ($destinationMatch.Count) {
    $destinationGroups = Invoke-JsonCommand -Command 'aws' -Arguments @(
      'cognito-idp','admin-list-groups-for-user','--user-pool-id',$context.destination.cognito_user_pool_id,
      '--username',$destinationMatch[0].Username,'--region',$context.destination.region,'--output','json','--no-cli-pager'
    )
    $destinationMembershipCount += @($destinationGroups.Groups).Count
  }
}

$result = [pscustomobject]@{
  SourceUsers                  = $sourceNames.Count
  DestinationUsers            = $destinationMappings.Count
  MissingSourceUsers          = $missing.Count
  SourceGroupMemberships      = $sourceMembershipCount
  DestinationGroupMemberships = $destinationMembershipCount
  Validation                  = if (-not $missing.Count -and $sourceMembershipCount -eq $destinationMembershipCount) { 'PASS' } else { 'FAIL' }
}
$result | Format-List
if ($result.Validation -ne 'PASS') { throw 'Cognito recovery validation failed.' }
