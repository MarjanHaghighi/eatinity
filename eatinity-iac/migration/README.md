# Eatinity enterprise recovery workflow

This package uses AWS Backup recovery points and cross-region copies. It does
not scan DynamoDB tables, download S3 data, or import application data through
JSON files. The only local JSON files are non-sensitive AWS job IDs/status
records under ignored `job-records/`.

## Architecture

```text
Main region resources
  -> source AWS Backup vault
  -> cross-region copy
  -> recovery-region AWS Backup vault
  -> native DynamoDB/S3 restore jobs
```

Terraform obtains source names from variables and calculates destination names
from the selected environment and region. PowerShell reads both through the
`recovery_configuration` and `backup_recovery` Terraform outputs.

## Terraform resources

The `modules/recovery_backup` module defines:

- Protected source and recovery AWS Backup vaults.
- Daily scheduled backup plan with cross-region copy.
- Explicit DynamoDB and S3 resource selection.
- Dedicated AWS Backup service role.
- AWS managed backup/restore policies, including S3 policies.
- 35-day source retention and 90-day recovery retention by default.

`enable_enterprise_backup` remains `false` until the source names and
prerequisites are confirmed. Enabling it creates chargeable backup resources.

## Prerequisites

- Source S3 buckets must have Versioning enabled.
- AWS Backup must be opted in for DynamoDB and S3 in the source region.
- Advanced DynamoDB backup features must be enabled for cross-region copies.
- The active identity must match the account reported by Terraform.
- Source table/bucket names in Terraform variables must be verified.
- Backup and restore storage, transfer, and request charges apply.

Run the read-only prerequisite test:

```powershell
.\Test-NativeBackupPrerequisites.ps1
```

## Native backup drill

After applying a reviewed plan with `enable_enterprise_backup = true`:

```powershell
.\Start-NativeBackup.ps1 -ConfirmNativeBackup
```

To start only one configured resource (for example, when resuming after a
partial run), pass its logical name. This prevents duplicate jobs for the
other resources:

```powershell
.\Start-NativeBackup.ps1 `
  -LogicalName website `
  -ConfirmNativeBackup
```

Valid logical names are `audit`, `categories`, `orders`, `products`, `users`,
`images`, and `website`.

Check each backup job using the returned job ID:

```powershell
.\Get-NativeRecoveryJobStatus.ps1 -JobType Backup -JobId '<job-id>'
```

After a job is `COMPLETED`, copy its recovery point:

```powershell
.\Start-NativeCopy.ps1 `
  -RecoveryPointArn '<source-recovery-point-arn>' `
  -ConfirmCrossRegionCopy
```

Monitor the copy:

```powershell
.\Get-NativeRecoveryJobStatus.ps1 -JobType Copy -JobId '<copy-job-id>'
```

## Native restore drill

DynamoDB native restore creates a new table and restores its indexes. It does
not load data into a pre-existing Terraform table. Use a unique drill name:

```powershell
.\Start-NativeRestore.ps1 `
  -RecoveryPointArn '<copied-recovery-point-arn>' `
  -ResourceType DynamoDB `
  -RestoreTargetName 'eatinity-recovery-drill-products-<timestamp>' `
  -ConfirmNativeRestore
```

S3 can restore into an existing versioned recovery bucket:

```powershell
.\Start-NativeRestore.ps1 `
  -RecoveryPointArn '<copied-recovery-point-arn>' `
  -ResourceType S3 `
  -RestoreTargetName '<Terraform output images_bucket_name>' `
  -ConfirmNativeRestore
```

Monitor restores:

```powershell
.\Get-NativeRecoveryJobStatus.ps1 -JobType Restore -JobId '<restore-job-id>'
```

After a successful DynamoDB drill, compare table/index/item counts and business
queries, record RTO/RPO evidence, and delete the drill table only through a
separately reviewed cleanup process. Do not point application traffic at a
restored table until its Terraform ownership/cutover strategy is approved.

For this project, after all restored/source counts match and every Terraform
destination table is confirmed empty, stream the restored records into the
application tables without creating a local data export:

```powershell
.\Copy-RestoredDynamoData.ps1 `
  -RestoreSuffix '20260721' `
  -ConfirmDestinationWrite
```

The script refuses to run against a non-empty destination, writes in DynamoDB
batches, retries unprocessed writes, validates final counts, and saves only a
non-sensitive result record under `job-records/`.

## Cognito

AWS Backup does not back up Cognito user pools. Passwords cannot be exported.
Terraform recreates the pool, client, policies, and standard recovery groups.
Synchronize transferable profiles and memberships with source-read and
destination-write controls:

```powershell
.\Sync-CognitoRecoveryUsers.ps1 -ConfirmDestinationUserWrite
.\Test-CognitoRecoveryUsers.ps1
```

The synchronization never deletes users or groups and suppresses welcome
messages. Passwords, active sessions, refresh tokens, and MFA secrets are not
copied. During an approved failover, send a reset code for one migrated user:

```powershell
.\Start-CognitoRecoveryPasswordReset.ps1 `
  -Username '<source Cognito username>' `
  -ConfirmPasswordResetMessage
```

## SES regional recovery

SES recovery is independently controlled by `enable_ses` and
`manage_ses_dns`. The Terraform module can create a regional domain identity,
DKIM, unique MAIL FROM records, a configuration set, and separate bounce and
complaint topics without changing the website DNS records. Keep both controls
false until the Route 53 zone and plan are reviewed.

After the regional identity is applied and verified, synchronize templates and
run the read-only check:

```powershell
.\Sync-SesRecoveryTemplates.ps1 -ConfirmDestinationTemplateWrite
.\Test-SesRecovery.ps1
```

SES production access and sending quotas are regional account settings and
must be requested/approved separately. Cognito passwords and MFA secrets are
not exportable and remain documented recovery limitations.
