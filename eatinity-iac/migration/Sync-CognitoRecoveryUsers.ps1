param(
  [string]$ConfigPath = (Join-Path $PSScriptRoot 'config.psd1'),
  [switch]$ConfirmDestinationUserWrite
)

. (Join-Path $PSScriptRoot 'NativeBackup.Common.ps1')
if (-not $ConfirmDestinationUserWrite) {
  throw 'Add -ConfirmDestinationUserWrite after reviewing the source and destination Cognito pool IDs.'
}

$context = Get-RecoveryContext -ConfigPath $ConfigPath
Assert-RecoveryAccount -Context $context
if ($context.source.cognito_user_pool_id -eq $context.destination.cognito_user_pool_id) {
  throw 'Source and destination Cognito pools must be different.'
}

Write-Host "READ-ONLY source: $($context.source.cognito_user_pool_id) [$($context.source.region)]"
Write-Host "WRITE destination: $($context.destination.cognito_user_pool_id) [$($context.destination.region)]"

function Get-CognitoAttributeValue {
  param([object[]]$Attributes, [string]$Name)
  $attribute = @($Attributes | Where-Object { $_.Name -eq $Name } | Select-Object -First 1)
  if (-not $attribute.Count) { return $null }
  return [string]$attribute[0].Value
}

$sourceUsersResult = Invoke-JsonCommand -Command 'aws' -Arguments @(
  'cognito-idp','list-users','--user-pool-id',$context.source.cognito_user_pool_id,
  '--region',$context.source.region,'--output','json','--no-cli-pager'
)
$sourceGroupsResult = Invoke-JsonCommand -Command 'aws' -Arguments @(
  'cognito-idp','list-groups','--user-pool-id',$context.source.cognito_user_pool_id,
  '--region',$context.source.region,'--output','json','--no-cli-pager'
)

$destinationGroupsResult = Invoke-JsonCommand -Command 'aws' -Arguments @(
  'cognito-idp','list-groups','--user-pool-id',$context.destination.cognito_user_pool_id,
  '--region',$context.destination.region,'--output','json','--no-cli-pager'
)
$destinationGroupNames = @($destinationGroupsResult.Groups | ForEach-Object GroupName)

foreach ($group in @($sourceGroupsResult.Groups)) {
  if ($group.GroupName -in $destinationGroupNames) { continue }
  $arguments = @(
    'cognito-idp','create-group','--group-name',$group.GroupName,
    '--user-pool-id',$context.destination.cognito_user_pool_id,
    '--region',$context.destination.region,'--output','json','--no-cli-pager'
  )
  $descriptionProperty = $group.PSObject.Properties['Description']
  if ($null -ne $descriptionProperty -and -not [string]::IsNullOrWhiteSpace([string]$descriptionProperty.Value)) {
    $arguments += @('--description',[string]$descriptionProperty.Value)
  }
  $precedenceProperty = $group.PSObject.Properties['Precedence']
  if ($null -ne $precedenceProperty -and $null -ne $precedenceProperty.Value) {
    $arguments += @('--precedence',[string]$precedenceProperty.Value)
  }
  Invoke-JsonCommand -Command 'aws' -Arguments $arguments | Out-Null
  Write-Host "Created recovery group: $($group.GroupName)"
}

$created = 0; $updated = 0; $disabled = 0; $memberships = 0; $skippedAttributes = 0
foreach ($sourceUser in @($sourceUsersResult.Users)) {
  $destinationUsername = if ([string]$sourceUser.Username -match '^[^@\s]+@[^@\s]+\.[^@\s]+$') {
    [string]$sourceUser.Username
  } else {
    Get-CognitoAttributeValue -Attributes @($sourceUser.Attributes) -Name 'email'
  }
  if ([string]::IsNullOrWhiteSpace($destinationUsername)) {
    throw "Source Cognito user '$($sourceUser.Username)' has no email attribute required by the destination pool."
  }

  $attributes = @($sourceUser.Attributes | Where-Object {
    $_.Name -notin @('sub', 'identities')
  })
  $attributeFile = Join-Path $env:TEMP "eatinity-cognito-attributes-$([guid]::NewGuid().ToString('N')).json"
  try {
    [IO.File]::WriteAllText($attributeFile, (ConvertTo-Json -InputObject $attributes -Depth 10), [Text.UTF8Encoding]::new($false))
    $exists = $true
    try {
      Invoke-JsonCommand -Command 'aws' -Arguments @(
        'cognito-idp','admin-get-user','--user-pool-id',$context.destination.cognito_user_pool_id,
        '--username',$destinationUsername,'--region',$context.destination.region,
        '--output','json','--no-cli-pager'
      ) | Out-Null
    } catch {
      if ($_.Exception.Message -match 'UserNotFoundException') { $exists = $false } else { throw }
    }

    if (-not $exists) {
      $randomBytes = New-Object byte[] 24
      $randomGenerator = [Security.Cryptography.RandomNumberGenerator]::Create()
      try {
        $randomGenerator.GetBytes($randomBytes)
      }
      finally {
        $randomGenerator.Dispose()
      }
      $temporaryPassword = [Convert]::ToBase64String($randomBytes) + 'aA1!'
      Invoke-JsonCommand -Command 'aws' -Arguments @(
        'cognito-idp','admin-create-user','--user-pool-id',$context.destination.cognito_user_pool_id,
        '--username',$destinationUsername,'--user-attributes',"file://$attributeFile",
        '--temporary-password',$temporaryPassword,'--message-action','SUPPRESS',
        '--region',$context.destination.region,'--output','json','--no-cli-pager'
      ) | Out-Null
      $created++
    } elseif ($attributes.Count) {
      Invoke-JsonCommand -Command 'aws' -Arguments @(
        'cognito-idp','admin-update-user-attributes','--user-pool-id',$context.destination.cognito_user_pool_id,
        '--username',$destinationUsername,'--user-attributes',"file://$attributeFile",
        '--region',$context.destination.region,'--output','json','--no-cli-pager'
      ) | Out-Null
      $updated++
    }
  }
  finally {
    Remove-Item -LiteralPath $attributeFile -Force -ErrorAction SilentlyContinue
    $temporaryPassword = $null
  }

  $enableOperation = if ($sourceUser.Enabled) { 'admin-enable-user' } else { 'admin-disable-user' }
  Invoke-JsonCommand -Command 'aws' -Arguments @(
    'cognito-idp',$enableOperation,'--user-pool-id',$context.destination.cognito_user_pool_id,
    '--username',$destinationUsername,'--region',$context.destination.region,
    '--output','json','--no-cli-pager'
  ) | Out-Null
  if (-not $sourceUser.Enabled) { $disabled++ }

  $sourceMemberships = Invoke-JsonCommand -Command 'aws' -Arguments @(
    'cognito-idp','admin-list-groups-for-user','--user-pool-id',$context.source.cognito_user_pool_id,
    '--username',$sourceUser.Username,'--region',$context.source.region,
    '--output','json','--no-cli-pager'
  )
  foreach ($group in @($sourceMemberships.Groups)) {
    Invoke-JsonCommand -Command 'aws' -Arguments @(
      'cognito-idp','admin-add-user-to-group','--user-pool-id',$context.destination.cognito_user_pool_id,
      '--username',$destinationUsername,'--group-name',$group.GroupName,
      '--region',$context.destination.region,'--output','json','--no-cli-pager'
    ) | Out-Null
    $memberships++
  }
}

$result = [pscustomobject]@{
  SourceUserCount       = @($sourceUsersResult.Users).Count
  CreatedUsers          = $created
  UpdatedUsers          = $updated
  DisabledUsers         = $disabled
  GroupMembershipWrites = $memberships
  SourcePool            = $context.source.cognito_user_pool_id
  DestinationPool       = $context.destination.cognito_user_pool_id
  PasswordStrategy      = 'RESET_REQUIRED; passwords and MFA secrets are not copied'
}
$stamp = (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ')
$path = Write-JobRecord -Value $result -Directory $context.JobRecordRoot -Name "cognito-sync-$stamp.json"
$result | Format-List
Write-Host "Cognito recovery profile synchronization complete. Evidence: $path"
