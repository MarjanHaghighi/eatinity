param([string]$ConfigPath = (Join-Path $PSScriptRoot 'config.psd1'))

. (Join-Path $PSScriptRoot 'NativeBackup.Common.ps1')
$context = Get-RecoveryContext -ConfigPath $ConfigPath
Assert-RecoveryAccount -Context $context

$config = Import-PowerShellDataFile -LiteralPath (Resolve-Path -LiteralPath $ConfigPath)
$terraformRoot = Resolve-Path -LiteralPath (Join-Path $PSScriptRoot $config.TerraformRoot)
$outputs = Invoke-JsonCommand -Command 'terraform' -Arguments @("-chdir=$($terraformRoot.Path)", 'output', '-json')
$sesOutput = $outputs.PSObject.Properties | Where-Object Name -eq 'ses_recovery' | Select-Object -First 1
if (-not $sesOutput -or -not $sesOutput.Value.value) {
  throw 'SES recovery is not enabled/applied in Terraform.'
}
$domain = $sesOutput.Value.value.domain

$account = Invoke-JsonCommand -Command 'aws' -Arguments @(
  'sesv2','get-account','--region',$context.destination.region,'--output','json','--no-cli-pager'
)
$verification = Invoke-JsonCommand -Command 'aws' -Arguments @(
  'ses','get-identity-verification-attributes','--identities',$domain,
  '--region',$context.destination.region,'--output','json','--no-cli-pager'
)
$dkim = Invoke-JsonCommand -Command 'aws' -Arguments @(
  'ses','get-identity-dkim-attributes','--identities',$domain,
  '--region',$context.destination.region,'--output','json','--no-cli-pager'
)
$sourceTemplates = Invoke-JsonCommand -Command 'aws' -Arguments @(
  'ses','list-templates','--region',$context.source.region,'--output','json','--no-cli-pager'
)
$destinationTemplates = Invoke-JsonCommand -Command 'aws' -Arguments @(
  'ses','list-templates','--region',$context.destination.region,'--output','json','--no-cli-pager'
)

[pscustomobject]@{
  Region                    = $context.destination.region
  Domain                    = $domain
  VerificationStatus        = $verification.VerificationAttributes.$domain.VerificationStatus
  DkimEnabled               = $dkim.DkimAttributes.$domain.DkimEnabled
  DkimVerificationStatus    = $dkim.DkimAttributes.$domain.DkimVerificationStatus
  ProductionAccessEnabled   = $account.ProductionAccessEnabled
  SendingEnabled            = $account.SendingEnabled
  SourceTemplateCount       = @($sourceTemplates.TemplatesMetadata).Count
  DestinationTemplateCount  = @($destinationTemplates.TemplatesMetadata).Count
} | Format-List
