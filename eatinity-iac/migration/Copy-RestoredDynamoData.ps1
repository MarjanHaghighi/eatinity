param(
  [Parameter(Mandatory)][ValidatePattern('^\d{8}$')][string]$RestoreSuffix,
  [string]$ConfigPath = (Join-Path $PSScriptRoot 'config.psd1'),
  [switch]$ConfirmDestinationWrite
)

. (Join-Path $PSScriptRoot 'NativeBackup.Common.ps1')
if (-not $ConfirmDestinationWrite) {
  throw 'Add -ConfirmDestinationWrite after confirming restored counts match and destination tables are empty.'
}

function Get-OptionalPropertyValue {
  param([Parameter(Mandatory)]$InputObject, [Parameter(Mandatory)][string]$Name)
  foreach ($property in $InputObject.PSObject.Properties) {
    if ($property.Name -eq $Name) { return $property.Value }
  }
  return $null
}

$context = Get-RecoveryContext -ConfigPath $ConfigPath
Assert-RecoveryAccount -Context $context

$results = foreach ($logicalName in @('audit', 'categories', 'orders', 'products', 'users')) {
  $restoredTable = "eatinity-recovery-drill-$logicalName-$RestoreSuffix"
  $destinationTable = Get-OptionalPropertyValue -InputObject $context.destination.table_names -Name $logicalName
  if (-not $destinationTable) { throw "Destination table mapping '$logicalName' is unavailable." }
  $destinationTable = [string]$destinationTable

  $restoredDescription = Invoke-JsonCommand -Command 'aws' -Arguments @(
    'dynamodb','describe-table','--table-name',$restoredTable,
    '--region',$context.destination.region,'--output','json','--no-cli-pager'
  )
  if ($restoredDescription.Table.TableStatus -ne 'ACTIVE') {
    throw "Restored table $restoredTable is not ACTIVE."
  }

  Write-Host "Reading $restoredTable and writing $destinationTable"
  $scan = Invoke-JsonCommand -Command 'aws' -Arguments @(
    'dynamodb','scan','--table-name',$restoredTable,
    '--region',$context.destination.region,'--output','json','--no-cli-pager'
  )
  $items = @($scan.Items)

  $destinationDescription = Invoke-JsonCommand -Command 'aws' -Arguments @(
    'dynamodb','describe-table','--table-name',$destinationTable,
    '--region',$context.destination.region,'--output','json','--no-cli-pager'
  )
  $destinationBefore = Invoke-JsonCommand -Command 'aws' -Arguments @(
    'dynamodb','scan','--table-name',$destinationTable,'--select','COUNT',
    '--region',$context.destination.region,'--output','json','--no-cli-pager'
  )
  if ([int64]$destinationBefore.Count -eq $items.Count) {
    Write-Host "Skipping $destinationTable; expected record count is already present."
    [pscustomobject]@{
      LogicalName       = $logicalName
      RestoredTable     = $restoredTable
      DestinationTable  = $destinationTable
      RecordsCopied     = $items.Count
      SanitizedIndexKeys = 0
      Validation        = 'PASS (already complete)'
    }
    continue
  }
  if ([int64]$destinationBefore.Count -gt $items.Count) {
    throw "Destination table $destinationTable contains more records than the restored table; refusing to continue."
  }

  $keyNames = @($destinationDescription.Table.KeySchema | ForEach-Object AttributeName)
  $globalIndexes = Get-OptionalPropertyValue -InputObject $destinationDescription.Table -Name 'GlobalSecondaryIndexes'
  if ($globalIndexes) {
    foreach ($index in @($globalIndexes)) {
      $keyNames += @($index.KeySchema | ForEach-Object AttributeName)
    }
  }
  $localIndexes = Get-OptionalPropertyValue -InputObject $destinationDescription.Table -Name 'LocalSecondaryIndexes'
  if ($localIndexes) {
    foreach ($index in @($localIndexes)) {
      $keyNames += @($index.KeySchema | ForEach-Object AttributeName)
    }
  }
  $keyNames = @($keyNames | Sort-Object -Unique)

  $sanitizedIndexKeys = 0
  foreach ($item in $items) {
    foreach ($keyName in $keyNames) {
      $attribute = Get-OptionalPropertyValue -InputObject $item -Name $keyName
      if (-not $attribute) { continue }
      $stringValue = Get-OptionalPropertyValue -InputObject $attribute -Name 'S'
      $binaryValue = Get-OptionalPropertyValue -InputObject $attribute -Name 'B'
      if (($null -ne $stringValue -and [string]::IsNullOrEmpty([string]$stringValue)) -or
          ($null -ne $binaryValue -and [string]::IsNullOrEmpty([string]$binaryValue))) {
        $item.PSObject.Properties.Remove($keyName)
        $sanitizedIndexKeys++
      }
    }
  }

  for ($offset = 0; $offset -lt $items.Count; $offset += 25) {
    $last = [Math]::Min($offset + 24, $items.Count - 1)
    $writes = @($items[$offset..$last] | ForEach-Object {
      [pscustomobject]@{ PutRequest = [pscustomobject]@{ Item = $_ } }
    })
    $request = @{}; $request[$destinationTable] = $writes

    do {
      $requestFile = Join-Path $env:TEMP "eatinity-dynamodb-batch-$([guid]::NewGuid().ToString('N')).json"
      try {
        [IO.File]::WriteAllText(
          $requestFile,
          ($request | ConvertTo-Json -Depth 100 -Compress),
          [Text.UTF8Encoding]::new($false)
        )
        $response = Invoke-JsonCommand -Command 'aws' -Arguments @(
          'dynamodb','batch-write-item','--request-items',"file://$requestFile",
          '--region',$context.destination.region,'--output','json','--no-cli-pager'
        )
      }
      finally {
        Remove-Item -LiteralPath $requestFile -Force -ErrorAction SilentlyContinue
      }
      $unprocessedItems = Get-OptionalPropertyValue -InputObject $response -Name 'UnprocessedItems'
      $unprocessed = if ($unprocessedItems) { Get-OptionalPropertyValue -InputObject $unprocessedItems -Name $destinationTable } else { $null }
      if ($unprocessed -and @($unprocessed).Count) {
        Start-Sleep -Seconds 2
        $request = @{}; $request[$destinationTable] = @($unprocessed)
      } else {
        $request = $null
      }
    } while ($request)
  }

  $destinationCount = Invoke-JsonCommand -Command 'aws' -Arguments @(
    'dynamodb','scan','--table-name',$destinationTable,'--select','COUNT',
    '--region',$context.destination.region,'--output','json','--no-cli-pager'
  )
  if ([int64]$destinationCount.Count -ne $items.Count) {
    throw "Validation failed for ${destinationTable}: expected $($items.Count), found $($destinationCount.Count)."
  }

  [pscustomobject]@{
    LogicalName      = $logicalName
    RestoredTable    = $restoredTable
    DestinationTable = $destinationTable
    RecordsCopied    = $items.Count
    SanitizedIndexKeys = $sanitizedIndexKeys
    Validation       = 'PASS'
  }
}

$stamp = (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ')
$path = Write-JobRecord -Value $results -Directory $context.JobRecordRoot -Name "dynamodb-copy-$stamp.json"
$results | Format-Table -AutoSize
Write-Host "DynamoDB destination copy completed and validated. Evidence: $path"
