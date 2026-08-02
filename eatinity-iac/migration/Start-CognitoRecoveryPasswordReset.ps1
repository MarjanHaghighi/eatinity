param(
  [Parameter(Mandatory)][string]$Username,
  [string]$ConfigPath = (Join-Path $PSScriptRoot 'config.psd1'),
  [switch]$ConfirmPasswordResetMessage
)

. (Join-Path $PSScriptRoot 'NativeBackup.Common.ps1')
if (-not $ConfirmPasswordResetMessage) {
  throw 'Add -ConfirmPasswordResetMessage to send a password-reset code from the recovery Cognito pool.'
}
$context = Get-RecoveryContext -ConfigPath $ConfigPath
Assert-RecoveryAccount -Context $context

$user = Invoke-JsonCommand -Command 'aws' -Arguments @(
  'cognito-idp','admin-get-user',
  '--user-pool-id',$context.destination.cognito_user_pool_id,
  '--username',$Username,'--region',$context.destination.region,
  '--output','json','--no-cli-pager'
)

if ($user.UserStatus -eq 'FORCE_CHANGE_PASSWORD') {
  $randomBytes = New-Object byte[] 24
  $randomGenerator = [Security.Cryptography.RandomNumberGenerator]::Create()
  try {
    $randomGenerator.GetBytes($randomBytes)
  }
  finally {
    $randomGenerator.Dispose()
  }
  $temporaryPassword = [Convert]::ToBase64String($randomBytes) + 'aA1!'
  try {
    Invoke-JsonCommand -Command 'aws' -Arguments @(
      'cognito-idp','admin-create-user',
      '--user-pool-id',$context.destination.cognito_user_pool_id,
      '--username',$Username,'--temporary-password',$temporaryPassword,
      '--message-action','RESEND','--region',$context.destination.region,
      '--output','json','--no-cli-pager'
    ) | Out-Null
  }
  finally {
    $temporaryPassword = $null
    $randomBytes = $null
  }
  Write-Host "Recovery temporary-password invitation resent for $Username."
} else {
  Invoke-JsonCommand -Command 'aws' -Arguments @(
    'cognito-idp','admin-reset-user-password',
    '--user-pool-id',$context.destination.cognito_user_pool_id,
    '--username',$Username,'--region',$context.destination.region,
    '--output','json','--no-cli-pager'
  ) | Out-Null
  Write-Host "Recovery password-reset code requested for $Username."
}
