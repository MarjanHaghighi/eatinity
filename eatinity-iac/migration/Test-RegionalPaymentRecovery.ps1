param(
  [string]$ConfigPath = (Join-Path $PSScriptRoot 'config.psd1')
)

. (Join-Path $PSScriptRoot 'NativeBackup.Common.ps1')

function Get-OptionalPropertyValue {
  param([Parameter(Mandatory)]$InputObject, [Parameter(Mandatory)][string]$Name)
  $property = $InputObject.PSObject.Properties[$Name]
  if ($property) { return $property.Value }
  return $null
}

$context = Get-RecoveryContext -ConfigPath $ConfigPath
Assert-RecoveryAccount -Context $context

$config = Import-PowerShellDataFile -LiteralPath (Resolve-Path -LiteralPath $ConfigPath)
$terraformRoot = Resolve-Path -LiteralPath (Join-Path $PSScriptRoot $config.TerraformRoot)
$outputs = Invoke-JsonCommand -Command 'terraform' -Arguments @("-chdir=$($terraformRoot.Path)", 'output', '-json')

$region = [string]$context.destination.region
$ordersTable = [string]$context.destination.table_names.orders
$webhookUrl = [string]$outputs.stripe_webhook_url.value
$secretName = [string]$outputs.stripe_secret_name.value

if ($region -eq [string]$context.source.region) {
  throw 'The destination Region equals the source Region; refusing a recovery diagnostic.'
}

Write-Host 'Recovery payment diagnostic (read only)'
Write-Host "Destination Region: $region"
Write-Host "Orders table: $ordersTable"
Write-Host "Stripe webhook URL: $webhookUrl"

$table = Invoke-JsonCommand -Command 'aws' -Arguments @(
  'dynamodb','describe-table','--table-name',$ordersTable,
  '--region',$region,'--output','json','--no-cli-pager'
)
$paymentIndex = @($table.Table.GlobalSecondaryIndexes) |
  Where-Object IndexName -eq 'paymentStatus-paidAt-index' |
  Select-Object -First 1
if (-not $paymentIndex) {
  throw "The paymentStatus-paidAt-index index is missing from $ordersTable."
}

$scan = Invoke-JsonCommand -Command 'aws' -Arguments @(
  'dynamodb','scan','--table-name',$ordersTable,
  '--projection-expression','#ps, paidAt',
  '--expression-attribute-names','{"#ps":"paymentStatus"}',
  '--region',$region,'--output','json','--no-cli-pager'
)
$items = @($scan.Items)
while ($scan.LastEvaluatedKey) {
  $keyFile = Join-Path $env:TEMP "eatinity-payment-scan-$([guid]::NewGuid().ToString('N')).json"
  try {
    [IO.File]::WriteAllText($keyFile, ($scan.LastEvaluatedKey | ConvertTo-Json -Depth 20 -Compress), [Text.UTF8Encoding]::new($false))
    $scan = Invoke-JsonCommand -Command 'aws' -Arguments @(
      'dynamodb','scan','--table-name',$ordersTable,
      '--projection-expression','#ps, paidAt',
      '--expression-attribute-names','{"#ps":"paymentStatus"}',
      '--exclusive-start-key',"file://$keyFile",
      '--region',$region,'--output','json','--no-cli-pager'
    )
  }
  finally {
    Remove-Item -LiteralPath $keyFile -Force -ErrorAction SilentlyContinue
  }
  $items += @($scan.Items)
}

$statusCounts = @{}
$paidMissingPaidAt = 0
foreach ($item in $items) {
  $paymentAttribute = Get-OptionalPropertyValue -InputObject $item -Name 'paymentStatus'
  $paidAtAttribute = Get-OptionalPropertyValue -InputObject $item -Name 'paidAt'
  $paymentValue = if ($paymentAttribute) { Get-OptionalPropertyValue -InputObject $paymentAttribute -Name 'S' } else { $null }
  $paidAtValue = if ($paidAtAttribute) { Get-OptionalPropertyValue -InputObject $paidAtAttribute -Name 'S' } else { $null }
  $status = if ($paymentValue) { [string]$paymentValue } else { '(missing)' }
  if (-not $statusCounts.ContainsKey($status)) { $statusCounts[$status] = 0 }
  $statusCounts[$status]++
  if ($status -eq 'Paid' -and -not $paidAtValue) { $paidMissingPaidAt++ }
}

$secret = Invoke-JsonCommand -Command 'aws' -Arguments @(
  'secretsmanager','describe-secret','--secret-id',$secretName,
  '--region',$region,'--output','json','--no-cli-pager'
)

$result = [ordered]@{
  DestinationRegion = $region
  OrdersTable = $ordersTable
  TableStatus = [string]$table.Table.TableStatus
  PaymentIndexStatus = [string]$paymentIndex.IndexStatus
  StripeWebhookUrl = $webhookUrl
  StripeSecretName = [string]$secret.Name
  StripeSecretLastChanged = [string]$secret.LastChangedDate
  OrderCount = $items.Count
  PaymentStatusCounts = $statusCounts
  PaidOrdersMissingPaidAt = $paidMissingPaidAt
}

$stamp = (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ')
$path = Write-JobRecord -Value $result -Directory $context.JobRecordRoot -Name "regional-payment-check-$stamp.json"

$result | ConvertTo-Json -Depth 10
Write-Host "Evidence: $path"

if ($paidMissingPaidAt -gt 0) {
  throw "$paidMissingPaidAt paid order(s) are missing paidAt and cannot appear in the sales index."
}
if (($statusCounts['Pending Payment'] -as [int]) -gt 0 -and -not ($statusCounts['Paid'] -as [int])) {
  Write-Warning 'Only pending orders exist. Confirm that Stripe Test mode has a destination webhook endpoint using the URL above and that the destination secret contains that endpoint signing secret.'
}
