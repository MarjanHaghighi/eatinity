Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Invoke-JsonCommand {
  param([Parameter(Mandatory)][string]$Command, [Parameter(Mandatory)][string[]]$Arguments)
  # PowerShell 7 can promote native stderr into a terminating error while
  # ErrorActionPreference is Stop. Capture both streams, then evaluate the
  # native process exit code ourselves so callers receive the useful message.
  $previousErrorActionPreference = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  try {
    $output = & $Command @Arguments 2>&1
    $exitCode = $LASTEXITCODE
  }
  finally {
    $ErrorActionPreference = $previousErrorActionPreference
  }
  if ($exitCode -ne 0) { throw "$Command failed (exit $exitCode): $($output -join [Environment]::NewLine)" }
  return (($output -join [Environment]::NewLine) | ConvertFrom-Json)
}

function Get-RecoveryContext {
  param([Parameter(Mandatory)][string]$ConfigPath)
  $config = Import-PowerShellDataFile -LiteralPath (Resolve-Path -LiteralPath $ConfigPath)
  $root = Resolve-Path -LiteralPath (Join-Path $PSScriptRoot $config.TerraformRoot)
  $allOutputs = Invoke-JsonCommand -Command 'terraform' -Arguments @("-chdir=$($root.Path)", 'output', '-json')
  $recoveryOutput = $allOutputs.PSObject.Properties['recovery_configuration']
  if (-not $recoveryOutput -or -not $recoveryOutput.Value) {
    throw 'Terraform output recovery_configuration is unavailable. Apply the reviewed Terraform output/protection update first.'
  }
  $context = $recoveryOutput.Value.value

  # backup_recovery is intentionally absent from Terraform state until the
  # optional enterprise AWS Backup resources have been enabled and applied.
  $backup = $null
  $backupOutput = $allOutputs.PSObject.Properties['backup_recovery']
  if ($backupOutput -and $backupOutput.Value) {
    $backup = $backupOutput.Value.value
  }
  $context | Add-Member -NotePropertyName Backup -NotePropertyValue $backup
  $context | Add-Member -NotePropertyName JobRecordRoot -NotePropertyValue (Join-Path $PSScriptRoot $config.JobRecordRoot)
  return $context
}

function Assert-RecoveryAccount {
  param([Parameter(Mandatory)]$Context)
  $identity = Invoke-JsonCommand -Command 'aws' -Arguments @('sts','get-caller-identity','--output','json','--no-cli-pager')
  if ($identity.Account -ne $Context.account_id) {
    throw "Active AWS account $($identity.Account) differs from Terraform account $($Context.account_id)."
  }
  if ($Context.source.region -eq $Context.destination.region) {
    throw 'Source and destination regions must be different.'
  }
}

function Write-JobRecord {
  param([Parameter(Mandatory)]$Value, [Parameter(Mandatory)][string]$Directory, [Parameter(Mandatory)][string]$Name)
  New-Item -ItemType Directory -Path $Directory -Force | Out-Null
  $path = Join-Path $Directory $Name
  [IO.File]::WriteAllText($path, ($Value | ConvertTo-Json -Depth 20), [Text.UTF8Encoding]::new($false))
  return $path
}
