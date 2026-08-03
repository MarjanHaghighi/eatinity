#!/usr/bin/env bash
set -Eeuo pipefail

# Eatinity region-selectable deployment and disaster-recovery orchestrator.
# Safe default: configure/validate/plan only. Every AWS or Terraform mutation
# requires both --execute and --approve-region <destination-region>.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TF_ROOT="$ROOT_DIR/eatinity-iac/environments/production"
MIGRATION_ROOT="$ROOT_DIR/eatinity-iac/migration"
FRONTEND_ROOT="$ROOT_DIR/eatinity-frontend"
LAMBDA_ROOT="$ROOT_DIR/eatinity-prod/lambda"
RUNTIME_ROOT="$ROOT_DIR/.eatinity-recovery"

ACTION="${1:-help}"
if [[ $# -gt 0 ]]; then shift; fi

# Support both "./bootstrap.sh help" and the conventional
# "./bootstrap.sh --help" without requiring regional arguments.
if [[ "$ACTION" == "-h" || "$ACTION" == "--help" ]]; then
  ACTION="help"
fi

SOURCE_REGION="us-east-1"
DESTINATION_REGION=""
STATE_REGION=""
STATE_BUCKET=""
STATE_KEY=""
LOCK_TABLE=""
BACKUP_OPERATOR_USER=""
SOURCE_COGNITO_POOL="us-east-1_4hyzIbJTa"
PROJECT_NAME="eatinity"
ENVIRONMENT="prod"
EXECUTE=false
APPROVE_REGION=""
ALLOW_SOURCE_REGION=false
ENABLE_BACKUP=true
ENABLE_SES=false
MANAGE_SES_DNS=false
USE_CUSTOM_DOMAIN=false
MANAGE_PUBLIC_DNS=false
ACM_CERTIFICATE_ARN=""
CLOUDFRONT_WEB_ACL_ARN=""
RECOVERY_POINT_ARN=""
RESOURCE_TYPE=""
RESTORE_TARGET=""
JOB_TYPE=""
JOB_ID=""
RESTORE_SUFFIX=""
USERNAME=""

SOURCE_PRODUCTS="EatinityProducts"
SOURCE_CATEGORIES="EatinityCategories"
SOURCE_ORDERS="EatinityOrders"
SOURCE_AUDIT="EatinityAuditLog"
SOURCE_USERS="EatinityUsers"
SOURCE_IMAGES_BUCKET="eatinity-prod-s3-images"
SOURCE_WEBSITE_BUCKET="eatinity-prod-s3-website"

usage() {
  cat <<'EOF'
Usage:
  ./bootstrap.sh <action> --destination-region REGION [options]

Safe actions (no infrastructure mutation):
  configure              Create ignored regional tfvars/backend files.
  preflight              Check tools, AWS identity, source resources, and region.
  validate               Package Lambda code; run tests, Terraform fmt/validate.
  plan                   Initialize protected backend and create a saved plan.
  outputs                Display Terraform outputs after an applied deployment.
  payment-check          Diagnose destination payment/report readiness (read only).
  job-status             Describe a Backup, Copy, or Restore job.
  smoke-test             Test existing frontend and products API outputs.

Mutating actions (require --execute --approve-region REGION):
  create-state-backend   Create/version/encrypt/block-public-access on state bucket
                         and create the DynamoDB state-lock table.
  apply                  Apply only the saved regional Terraform plan.
  start-backups          Start native backups for all configured source resources.
  start-copy             Copy one completed recovery point to the recovery Region.
  start-restore          Restore one copied recovery point to an isolated target.
  migrate-dynamodb       Copy five validated drill tables into empty app tables.
  sync-cognito           Copy transferable users/groups to recovery Cognito.
  reset-cognito-user     Send a recovery password reset for one migrated user.
  sync-ses               Copy SES templates to the recovery Region.
  deploy-frontend        Build React, write runtime config, upload, invalidate CDN.

Required common options:
  --destination-region REGION
  --source-region REGION                  default: us-east-1
  --backup-operator-user IAM_USER
  --state-bucket NAME
  --state-region REGION                   default: destination Region
  --state-key KEY                         default: eatinity/recovery/REGION/terraform.tfstate
  --lock-table NAME                       default: eatinity-terraform-locks

Mutation authorization:
  --execute
  --approve-region REGION                 must exactly match destination

Job options:
  --job-type Backup|Copy|Restore --job-id ID
  --recovery-point-arn ARN
  --resource-type DynamoDB|S3 --restore-target NAME
  --restore-suffix YYYYMMDD
  --username COGNITO_USERNAME

Optional service flags:
  --disable-backup
  --enable-ses
  --manage-ses-dns
  --use-custom-domain --acm-certificate-arn ARN
  --manage-public-dns
  --cloudfront-web-acl-arn ARN
  --allow-source-region                    exceptional; never use for a DR drill

Examples:
  ./bootstrap.sh plan --destination-region ca-central-1 \
    --backup-operator-user marjan-admin --state-bucket MY-STATE-BUCKET

  ./bootstrap.sh apply --destination-region ca-central-1 \
    --backup-operator-user marjan-admin --state-bucket MY-STATE-BUCKET \
    --execute --approve-region ca-central-1
EOF
}

die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
note() { printf '\n==> %s\n' "$*"; }
need() { command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --source-region) SOURCE_REGION="$2"; shift 2 ;;
    --destination-region) DESTINATION_REGION="$2"; shift 2 ;;
    --state-region) STATE_REGION="$2"; shift 2 ;;
    --state-bucket) STATE_BUCKET="$2"; shift 2 ;;
    --state-key) STATE_KEY="$2"; shift 2 ;;
    --lock-table) LOCK_TABLE="$2"; shift 2 ;;
    --backup-operator-user) BACKUP_OPERATOR_USER="$2"; shift 2 ;;
    --source-cognito-pool) SOURCE_COGNITO_POOL="$2"; shift 2 ;;
    --project-name) PROJECT_NAME="$2"; shift 2 ;;
    --environment) ENVIRONMENT="$2"; shift 2 ;;
    --execute) EXECUTE=true; shift ;;
    --approve-region) APPROVE_REGION="$2"; shift 2 ;;
    --allow-source-region) ALLOW_SOURCE_REGION=true; shift ;;
    --disable-backup) ENABLE_BACKUP=false; shift ;;
    --enable-ses) ENABLE_SES=true; shift ;;
    --manage-ses-dns) MANAGE_SES_DNS=true; shift ;;
    --use-custom-domain) USE_CUSTOM_DOMAIN=true; shift ;;
    --manage-public-dns) MANAGE_PUBLIC_DNS=true; shift ;;
    --acm-certificate-arn) ACM_CERTIFICATE_ARN="$2"; shift 2 ;;
    --cloudfront-web-acl-arn) CLOUDFRONT_WEB_ACL_ARN="$2"; shift 2 ;;
    --recovery-point-arn) RECOVERY_POINT_ARN="$2"; shift 2 ;;
    --resource-type) RESOURCE_TYPE="$2"; shift 2 ;;
    --restore-target) RESTORE_TARGET="$2"; shift 2 ;;
    --job-type) JOB_TYPE="$2"; shift 2 ;;
    --job-id) JOB_ID="$2"; shift 2 ;;
    --restore-suffix) RESTORE_SUFFIX="$2"; shift 2 ;;
    --username) USERNAME="$2"; shift 2 ;;
    --source-products-table) SOURCE_PRODUCTS="$2"; shift 2 ;;
    --source-categories-table) SOURCE_CATEGORIES="$2"; shift 2 ;;
    --source-orders-table) SOURCE_ORDERS="$2"; shift 2 ;;
    --source-audit-table) SOURCE_AUDIT="$2"; shift 2 ;;
    --source-users-table) SOURCE_USERS="$2"; shift 2 ;;
    --source-images-bucket) SOURCE_IMAGES_BUCKET="$2"; shift 2 ;;
    --source-website-bucket) SOURCE_WEBSITE_BUCKET="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) die "Unknown option: $1" ;;
  esac
done

[[ "$ACTION" == "help" ]] && { usage; exit 0; }
[[ -n "$DESTINATION_REGION" ]] || die "--destination-region is required"
[[ "$DESTINATION_REGION" =~ ^[a-z]{2}(-gov)?-[a-z]+-[0-9]+$ ]] || die "Invalid destination Region format"
[[ "$SOURCE_REGION" =~ ^[a-z]{2}(-gov)?-[a-z]+-[0-9]+$ ]] || die "Invalid source Region format"
[[ "$ENVIRONMENT" == "prod" ]] || die "Current Terraform root requires --environment prod"

STATE_REGION="${STATE_REGION:-$DESTINATION_REGION}"
STATE_KEY="${STATE_KEY:-eatinity/recovery/$DESTINATION_REGION/terraform.tfstate}"
LOCK_TABLE="${LOCK_TABLE:-eatinity-terraform-locks}"
REGION_DIR="$RUNTIME_ROOT/$DESTINATION_REGION"
TFVARS_FILE="$REGION_DIR/terraform.tfvars"
BACKEND_FILE="$REGION_DIR/backend.hcl"
PLAN_FILE="$REGION_DIR/eatinity-$DESTINATION_REGION.tfplan"
CONFIG_FILE="$MIGRATION_ROOT/config.psd1"

mutation_guard() {
  [[ "$EXECUTE" == true ]] || die "This action changes AWS. Re-run with --execute."
  [[ "$APPROVE_REGION" == "$DESTINATION_REGION" ]] || die "--approve-region must exactly equal $DESTINATION_REGION"
  if [[ "$DESTINATION_REGION" == "$SOURCE_REGION" && "$ALLOW_SOURCE_REGION" != true ]]; then
    die "Source-region deployment is blocked. Choose a different recovery Region."
  fi
}

require_backend_values() {
  [[ -n "$STATE_BUCKET" ]] || die "--state-bucket is required for this action"
  [[ -n "$STATE_REGION" ]] || die "--state-region is required"
}

require_operator() {
  [[ -n "$BACKUP_OPERATOR_USER" ]] || die "--backup-operator-user is required"
}

write_configuration() {
  require_operator
  mkdir -p "$REGION_DIR"
  cat >"$TFVARS_FILE" <<EOF
aws_region                 = "$DESTINATION_REGION"
source_aws_region          = "$SOURCE_REGION"
allow_main_region_deployment = $( [[ "$ALLOW_SOURCE_REGION" == true ]] && echo true || echo false )
project_name               = "$PROJECT_NAME"
environment                = "$ENVIRONMENT"
enable_enterprise_backup   = $ENABLE_BACKUP
backup_operator_user_name  = "$BACKUP_OPERATOR_USER"
source_cognito_user_pool_id = "$SOURCE_COGNITO_POOL"

source_table_names = {
  products   = "$SOURCE_PRODUCTS"
  categories = "$SOURCE_CATEGORIES"
  orders     = "$SOURCE_ORDERS"
  audit      = "$SOURCE_AUDIT"
  users      = "$SOURCE_USERS"
}
source_bucket_names = {
  images  = "$SOURCE_IMAGES_BUCKET"
  website = "$SOURCE_WEBSITE_BUCKET"
}

disposable_environment        = false
force_destroy_buckets         = false
enable_deletion_protection    = true
enable_point_in_time_recovery = true
enable_s3_versioning          = true
cloudwatch_log_retention_days = 30

create_cognito_resources = true
allowed_origins          = ["http://localhost:3000", "http://localhost:5173"]
cognito_callback_urls    = ["http://localhost:3000", "http://localhost:5173"]
cognito_logout_urls      = ["http://localhost:3000", "http://localhost:5173"]

use_custom_domain      = $USE_CUSTOM_DOMAIN
manage_public_dns      = $MANAGE_PUBLIC_DNS
acm_certificate_arn    = $( [[ -n "$ACM_CERTIFICATE_ARN" ]] && printf '"%s"' "$ACM_CERTIFICATE_ARN" || printf 'null' )
cloudfront_web_acl_arn = $( [[ -n "$CLOUDFRONT_WEB_ACL_ARN" ]] && printf '"%s"' "$CLOUDFRONT_WEB_ACL_ARN" || printf 'null' )

enable_ses         = $ENABLE_SES
manage_ses_dns     = $MANAGE_SES_DNS
ses_from_email     = "orders@eatinity.ca"
secret_recovery_window_days = 7
EOF

  if [[ -n "$STATE_BUCKET" ]]; then
    cat >"$BACKEND_FILE" <<EOF
bucket         = "$STATE_BUCKET"
key            = "$STATE_KEY"
region         = "$STATE_REGION"
encrypt        = true
dynamodb_table = "$LOCK_TABLE"
EOF
  fi
  note "Wrote ignored configuration under $REGION_DIR"
}

package_lambdas() {
  need zip
  local mappings=(
    "products:get_products" "admin_menu:admin_menu" "admin_orders:admin_orders"
    "admin_users:admin_users" "sales_reports:sales_reports" "admin_audit:admin_audit"
    "stripe_checkout:stripe_checkout" "stripe_webhook:stripe_webhook" "user_profile:user_profile"
  )
  for entry in "${mappings[@]}"; do
    local folder="${entry%%:*}" archive="${entry##*:}"
    [[ -d "$LAMBDA_ROOT/$folder" ]] || die "Missing Lambda folder: $folder"
    (cd "$LAMBDA_ROOT/$folder" && zip -qr "$LAMBDA_ROOT/$archive.zip" . -x '*__pycache__*' '*.pyc')
  done
}

terraform_init() {
  require_backend_values
  [[ -f "$BACKEND_FILE" ]] || write_configuration
  terraform -chdir="$TF_ROOT" init -reconfigure -backend-config="$BACKEND_FILE"
}

pwsh_run() {
  need pwsh
  pwsh -NoLogo -NoProfile -File "$@"
}

case "$ACTION" in
  configure)
    write_configuration
    ;;

  preflight)
    need aws; need terraform; need jq; need node; need npm; need zip; need pwsh
    require_operator
    write_configuration
    note "Active AWS identity"
    aws sts get-caller-identity --output json --no-cli-pager | jq '{Account,Arn}'
    [[ "$SOURCE_REGION" != "$DESTINATION_REGION" || "$ALLOW_SOURCE_REGION" == true ]] || die "Source and destination must differ"
    note "Checking configured source resources (read only)"
    for table in "$SOURCE_PRODUCTS" "$SOURCE_CATEGORIES" "$SOURCE_ORDERS" "$SOURCE_AUDIT" "$SOURCE_USERS"; do
      aws dynamodb describe-table --table-name "$table" --region "$SOURCE_REGION" --query 'Table.[TableName,TableStatus]' --output table --no-cli-pager
    done
    for bucket in "$SOURCE_IMAGES_BUCKET" "$SOURCE_WEBSITE_BUCKET"; do
      aws s3api get-bucket-versioning --bucket "$bucket" --region "$SOURCE_REGION" --output json --no-cli-pager
    done
    aws backup describe-region-settings --region "$SOURCE_REGION" --output json --no-cli-pager | jq '.ResourceTypeOptInPreference | {DynamoDB,S3}'
    ;;

  validate)
    need terraform; need node; need npm; need python; need zip
    write_configuration
    package_lambdas
    (cd "$FRONTEND_ROOT" && npm ci && npm run lint && npm run build)
    (cd "$ROOT_DIR/eatinity-prod" && python -m unittest discover -s tests -v)
    terraform fmt -check -recursive "$ROOT_DIR/eatinity-iac"
    terraform -chdir="$TF_ROOT" init -backend=false
    terraform -chdir="$TF_ROOT" validate
    ;;

  create-state-backend)
    need aws; mutation_guard; require_backend_values; require_operator
    note "Creating protected Terraform backend in $STATE_REGION"
    if [[ "$STATE_REGION" == "us-east-1" ]]; then
      aws s3api create-bucket --bucket "$STATE_BUCKET" --region "$STATE_REGION" --no-cli-pager 2>/dev/null || true
    else
      aws s3api create-bucket --bucket "$STATE_BUCKET" --region "$STATE_REGION" --create-bucket-configuration LocationConstraint="$STATE_REGION" --no-cli-pager 2>/dev/null || true
    fi
    aws s3api put-bucket-versioning --bucket "$STATE_BUCKET" --versioning-configuration Status=Enabled --region "$STATE_REGION" --no-cli-pager
    aws s3api put-bucket-encryption --bucket "$STATE_BUCKET" --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}' --region "$STATE_REGION" --no-cli-pager
    aws s3api put-public-access-block --bucket "$STATE_BUCKET" --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true --region "$STATE_REGION" --no-cli-pager
    aws dynamodb describe-table --table-name "$LOCK_TABLE" --region "$STATE_REGION" --no-cli-pager >/dev/null 2>&1 || \
      aws dynamodb create-table --table-name "$LOCK_TABLE" --attribute-definitions AttributeName=LockID,AttributeType=S --key-schema AttributeName=LockID,KeyType=HASH --billing-mode PAY_PER_REQUEST --region "$STATE_REGION" --no-cli-pager
    aws dynamodb wait table-exists --table-name "$LOCK_TABLE" --region "$STATE_REGION"
    write_configuration
    ;;

  plan)
    need aws; need terraform; need zip; require_backend_values; require_operator
    write_configuration; package_lambdas; terraform_init
    terraform -chdir="$TF_ROOT" fmt -check -recursive
    terraform -chdir="$TF_ROOT" validate
    terraform -chdir="$TF_ROOT" plan -var-file="$TFVARS_FILE" -out="$PLAN_FILE"
    terraform -chdir="$TF_ROOT" show -no-color "$PLAN_FILE" >"$REGION_DIR/plan.txt"
    note "Review $REGION_DIR/plan.txt. It must contain only the intended destination stack and explicitly reviewed source backup resources."
    ;;

  apply)
    need terraform; mutation_guard; require_backend_values; require_operator
    [[ -f "$PLAN_FILE" ]] || die "Saved plan not found. Run the plan action first."
    write_configuration; terraform_init
    terraform -chdir="$TF_ROOT" apply "$PLAN_FILE"
    ;;

  outputs)
    need terraform; require_backend_values; write_configuration; terraform_init
    terraform -chdir="$TF_ROOT" output
    ;;

  payment-check)
    require_backend_values; write_configuration; terraform_init
    pwsh_run "$MIGRATION_ROOT/Test-RegionalPaymentRecovery.ps1" -ConfigPath "$CONFIG_FILE"
    ;;

  start-backups)
    mutation_guard; require_backend_values; write_configuration; terraform_init
    pwsh_run "$MIGRATION_ROOT/Start-NativeBackup.ps1" -ConfigPath "$CONFIG_FILE" -ConfirmNativeBackup
    ;;

  job-status)
    [[ "$JOB_TYPE" =~ ^(Backup|Copy|Restore)$ ]] || die "--job-type must be Backup, Copy, or Restore"
    [[ -n "$JOB_ID" ]] || die "--job-id is required"
    require_backend_values; write_configuration; terraform_init
    pwsh_run "$MIGRATION_ROOT/Get-NativeRecoveryJobStatus.ps1" -JobType "$JOB_TYPE" -JobId "$JOB_ID" -ConfigPath "$CONFIG_FILE"
    ;;

  start-copy)
    mutation_guard; [[ -n "$RECOVERY_POINT_ARN" ]] || die "--recovery-point-arn is required"
    require_backend_values; write_configuration; terraform_init
    pwsh_run "$MIGRATION_ROOT/Start-NativeCopy.ps1" -RecoveryPointArn "$RECOVERY_POINT_ARN" -ConfigPath "$CONFIG_FILE" -ConfirmCrossRegionCopy
    ;;

  start-restore)
    mutation_guard; [[ -n "$RECOVERY_POINT_ARN" ]] || die "--recovery-point-arn is required"
    [[ "$RESOURCE_TYPE" =~ ^(DynamoDB|S3)$ ]] || die "--resource-type must be DynamoDB or S3"
    [[ -n "$RESTORE_TARGET" ]] || die "--restore-target is required"
    require_backend_values; write_configuration; terraform_init
    pwsh_run "$MIGRATION_ROOT/Start-NativeRestore.ps1" -RecoveryPointArn "$RECOVERY_POINT_ARN" -ResourceType "$RESOURCE_TYPE" -RestoreTargetName "$RESTORE_TARGET" -ConfigPath "$CONFIG_FILE" -ConfirmNativeRestore
    ;;

  migrate-dynamodb)
    mutation_guard; [[ "$RESTORE_SUFFIX" =~ ^[0-9]{8}$ ]] || die "--restore-suffix must be YYYYMMDD"
    require_backend_values; write_configuration; terraform_init
    pwsh_run "$MIGRATION_ROOT/Copy-RestoredDynamoData.ps1" -RestoreSuffix "$RESTORE_SUFFIX" -ConfigPath "$CONFIG_FILE" -ConfirmDestinationWrite
    ;;

  sync-cognito)
    mutation_guard; require_backend_values; write_configuration; terraform_init
    pwsh_run "$MIGRATION_ROOT/Sync-CognitoRecoveryUsers.ps1" -ConfigPath "$CONFIG_FILE" -ConfirmDestinationUserWrite
    pwsh_run "$MIGRATION_ROOT/Test-CognitoRecoveryUsers.ps1" -ConfigPath "$CONFIG_FILE"
    ;;

  reset-cognito-user)
    mutation_guard; [[ -n "$USERNAME" ]] || die "--username is required"
    require_backend_values; write_configuration; terraform_init
    pwsh_run "$MIGRATION_ROOT/Start-CognitoRecoveryPasswordReset.ps1" -Username "$USERNAME" -ConfigPath "$CONFIG_FILE" -ConfirmPasswordResetMessage
    ;;

  sync-ses)
    mutation_guard; [[ "$ENABLE_SES" == true ]] || die "Re-run with --enable-ses after SES/DNS review"
    require_backend_values; write_configuration; terraform_init
    pwsh_run "$MIGRATION_ROOT/Sync-SesRecoveryTemplates.ps1" -ConfigPath "$CONFIG_FILE" -ConfirmDestinationTemplateWrite
    pwsh_run "$MIGRATION_ROOT/Test-SesRecovery.ps1" -ConfigPath "$CONFIG_FILE"
    ;;

  deploy-frontend)
    mutation_guard; require_backend_values; write_configuration; terraform_init
    pwsh_run "$MIGRATION_ROOT/Deploy-RegionalFrontend.ps1" -ConfigPath "$CONFIG_FILE" -ConfirmFrontendDeployment
    ;;

  smoke-test)
    need terraform; need curl; require_backend_values; write_configuration; terraform_init
    FRONTEND_URL="$(terraform -chdir="$TF_ROOT" output -raw frontend_base_url)"
    PRODUCTS_URL="$(terraform -chdir="$TF_ROOT" output -raw products_api_url)"
    curl --fail --location --retry 5 --retry-delay 5 "$FRONTEND_URL"
    curl --fail --location --retry 5 --retry-delay 5 "$PRODUCTS_URL"
    note "Smoke tests passed: $FRONTEND_URL and $PRODUCTS_URL"
    ;;

  *) die "Unknown action: $ACTION. Run ./bootstrap.sh --help" ;;
esac
