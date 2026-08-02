param(
  [string]$ConfigPath = (Join-Path $PSScriptRoot 'config.psd1'),
  [switch]$ConfirmFrontendDeployment
)

. (Join-Path $PSScriptRoot 'NativeBackup.Common.ps1')
if (-not $ConfirmFrontendDeployment) {
  throw 'Add -ConfirmFrontendDeployment after applying and reviewing the dynamic frontend/Lambda Terraform update.'
}

$config = Import-PowerShellDataFile -LiteralPath (Resolve-Path -LiteralPath $ConfigPath)
$terraformRoot = Resolve-Path -LiteralPath (Join-Path $PSScriptRoot $config.TerraformRoot)
$frontendRoot = Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../../eatinity-frontend')
$outputs = Invoke-JsonCommand -Command 'terraform' -Arguments @("-chdir=$($terraformRoot.Path)", 'output', '-json')

$required = @(
  'api_endpoint', 'aws_region', 'cognito_client_id', 'cognito_user_pool_id',
  'cloudfront_distribution_id', 'frontend_base_url', 'images_bucket_name', 'website_bucket_name'
)
foreach ($name in $required) {
  $property = $outputs.PSObject.Properties | Where-Object Name -eq $name | Select-Object -First 1
  if (-not $property -or -not $property.Value.value) { throw "Terraform output '$name' is unavailable." }
}

$runtimeConfig = [ordered]@{
  apiBaseUrl       = [string]$outputs.api_endpoint.value
  imageBaseUrl     = "https://$($outputs.images_bucket_name.value).s3.$($outputs.aws_region.value).amazonaws.com/"
  awsRegion        = [string]$outputs.aws_region.value
  cognitoUserPoolId = [string]$outputs.cognito_user_pool_id.value
  cognitoClientId   = [string]$outputs.cognito_client_id.value
}

Push-Location $frontendRoot.Path
try {
  & npm run build
  if ($LASTEXITCODE -ne 0) { throw "Frontend build failed with exit code $LASTEXITCODE." }
}
finally {
  Pop-Location
}

$distRoot = Join-Path $frontendRoot.Path 'dist'
$runtimePath = Join-Path $distRoot 'runtime-config.js'
$runtimeJavascript = "window.__EATINITY_CONFIG__ = $($runtimeConfig | ConvertTo-Json -Compress);"
[IO.File]::WriteAllText($runtimePath, $runtimeJavascript, [Text.UTF8Encoding]::new($false))

& aws s3 sync $distRoot "s3://$($outputs.website_bucket_name.value)" --region $outputs.aws_region.value --no-progress
if ($LASTEXITCODE -ne 0) { throw "Frontend S3 deployment failed with exit code $LASTEXITCODE." }

$invalidation = Invoke-JsonCommand -Command 'aws' -Arguments @(
  'cloudfront','create-invalidation','--distribution-id',$outputs.cloudfront_distribution_id.value,
  '--paths','/*','--output','json','--no-cli-pager'
)

Write-Host "Regional frontend deployed: $($outputs.frontend_base_url.value)"
Write-Host "API: $($runtimeConfig.apiBaseUrl)"
Write-Host "CloudFront invalidation: $($invalidation.Invalidation.Id)"
