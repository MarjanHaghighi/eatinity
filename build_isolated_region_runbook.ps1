param(
  [string]$OutputPath = "C:\Marjan\Eatinity\Eatinity_Isolated_Region_Deployment_Runbook.docx"
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.IO.Compression.FileSystem
Add-Type -AssemblyName System.IO.Compression

function XmlEscape([string]$Text) {
  return [System.Security.SecurityElement]::Escape($Text)
}

function RunXml([string]$Text, [switch]$Bold, [switch]$Italic, [string]$Color = "", [string]$Font = "Calibri", [int]$Size = 22) {
  $props = "<w:rFonts w:ascii=`"$Font`" w:hAnsi=`"$Font`"/><w:sz w:val=`"$Size`"/><w:szCs w:val=`"$Size`"/>"
  if ($Bold) { $props += "<w:b/>" }
  if ($Italic) { $props += "<w:i/>" }
  if ($Color) { $props += "<w:color w:val=`"$Color`"/>" }
  return "<w:r><w:rPr>$props</w:rPr><w:t xml:space=`"preserve`">$(XmlEscape $Text)</w:t></w:r>"
}

function ParagraphXml([string]$Text, [string]$Style = "Normal", [string]$Align = "", [switch]$Bold, [switch]$Italic, [string]$Color = "", [int]$Size = 0, [switch]$KeepNext, [string]$Shade = "") {
  $pPr = "<w:pStyle w:val=`"$Style`"/>"
  if ($Align) { $pPr += "<w:jc w:val=`"$Align`"/>" }
  if ($KeepNext) { $pPr += "<w:keepNext/>" }
  if ($Shade) { $pPr += "<w:shd w:val=`"clear`" w:color=`"auto`" w:fill=`"$Shade`"/><w:ind w:left=`"120`" w:right=`"120`"/><w:spacing w:before=`"100`" w:after=`"100`"/>" }
  $runSize = if ($Size -gt 0) { $Size } else { 22 }
  return "<w:p><w:pPr>$pPr</w:pPr>$(RunXml -Text $Text -Bold:$Bold -Italic:$Italic -Color $Color -Size $runSize)</w:p>"
}

function ListItemXml([string]$Text, [int]$Number = 1, [switch]$Bullet) {
  $numId = if ($Bullet) { 2 } else { 1 }
  return "<w:p><w:pPr><w:pStyle w:val=`"ListParagraph`"/><w:numPr><w:ilvl w:val=`"0`"/><w:numId w:val=`"$numId`"/></w:numPr></w:pPr>$(RunXml $Text)</w:p>"
}

function CodeXml([string]$Text) {
  return "<w:p><w:pPr><w:pStyle w:val=`"Code`"/></w:pPr>$(RunXml -Text $Text -Font "Consolas" -Size 19)</w:p>"
}

function PageBreakXml() {
  return '<w:p><w:r><w:br w:type="page"/></w:r></w:p>'
}

function CellXml([string]$Text, [int]$Width, [switch]$Header) {
  $fill = if ($Header) { '<w:shd w:val="clear" w:color="auto" w:fill="E8EEF5"/>' } else { '' }
  $bold = if ($Header) { '<w:b/>' } else { '' }
  return "<w:tc><w:tcPr><w:tcW w:w=`"$Width`" w:type=`"dxa`"/>$fill<w:tcMar><w:top w:w=`"80`" w:type=`"dxa`"/><w:left w:w=`"120`" w:type=`"dxa`"/><w:bottom w:w=`"80`" w:type=`"dxa`"/><w:right w:w=`"120`" w:type=`"dxa`"/></w:tcMar><w:vAlign w:val=`"center`"/></w:tcPr><w:p><w:r><w:rPr><w:rFonts w:ascii=`"Calibri`" w:hAnsi=`"Calibri`"/><w:sz w:val=`"20`"/>$bold</w:rPr><w:t>$(XmlEscape $Text)</w:t></w:r></w:p></w:tc>"
}

function IsolationTableXml() {
  $rows = @(
    @("Area", "Isolation requirement", $true),
    @("AWS Region", "Use a target such as ca-central-1; verify every regional service supports it.", $false),
    @("Terraform state", "Use a new local file or a different backend key. Never copy either existing tfstate file.", $false),
    @("S3", "Use globally unique DR bucket names; existing bucket names cannot be reused.", $false),
    @("DynamoDB", "Use new DR table names so imports and accidental updates are impossible.", $false),
    @("Cognito", "Create a new user pool and app client in the target region. Existing us-east-1 IDs cannot be reused.", $false),
    @("CloudFront/DNS", "Create a new distribution without eatinity.ca aliases. Keep public DNS management disabled.", $false),
    @("Stripe", "Use test-mode secrets and a separate webhook endpoint for the new API.", $false),
    @("IAM", "Do not attach policies to LabRole unless the lab permits it and the change is explicitly reviewed.", $false)
  )
  $xml = '<w:tbl><w:tblPr><w:tblW w:w="9360" w:type="dxa"/><w:tblInd w:w="120" w:type="dxa"/><w:tblBorders><w:top w:val="single" w:sz="4" w:color="B8C6D5"/><w:left w:val="single" w:sz="4" w:color="B8C6D5"/><w:bottom w:val="single" w:sz="4" w:color="B8C6D5"/><w:right w:val="single" w:sz="4" w:color="B8C6D5"/><w:insideH w:val="single" w:sz="4" w:color="D7E0E8"/><w:insideV w:val="single" w:sz="4" w:color="D7E0E8"/></w:tblBorders><w:tblLayout w:type="fixed"/></w:tblPr><w:tblGrid><w:gridCol w:w="2700"/><w:gridCol w:w="6660"/></w:tblGrid>'
  foreach ($row in $rows) {
    $xml += '<w:tr>' + (CellXml $row[0] 2700 -Header:$row[2]) + (CellXml $row[1] 6660 -Header:$row[2]) + '</w:tr>'
  }
  return $xml + '</w:tbl>'
}

$body = New-Object System.Collections.Generic.List[string]
$body.Add((ParagraphXml "EATINITY ISOLATED-REGION DEPLOYMENT RUNBOOK" "Title" "left" -Bold -Color "1F4D78" -Size 34 -KeepNext))
$body.Add((ParagraphXml "How to create a separate Terraform-managed recovery/test stack without touching the existing project" "Subtitle" "left" -Color "4F6475" -Size 24))
$body.Add((ParagraphXml "Prepared for: Eatinity / CAA900   |   Date: July 20, 2026   |   Status: Safety-first procedure" "Metadata"))
$body.Add((ParagraphXml "PRIMARY SAFETY RULE" "Heading1" -KeepNext))
$body.Add((ParagraphXml "Use a new directory, a new state, a different AWS region, unique resource names, and no imports. Before any apply, the plan must contain CREATE actions only - no update, replace, or destroy actions against existing Eatinity resources." "Normal" -Bold -Color "8A2D1E" -Shade "FDECEC"))
$body.Add((ParagraphXml "Important project-specific finding" "Heading2" -KeepNext))
$body.Add((ParagraphXml "The current eatinity-iac configuration is not yet a fully greenfield multi-region module. It reads an existing Cognito user pool by ID, expects an existing ACM certificate for eatinity.ca, and uses globally unique S3 names. Those settings must be isolated before deploying in another region."))
$body.Add((ParagraphXml "Isolation design" "Heading1" -KeepNext))
$body.Add((IsolationTableXml))

$body.Add((PageBreakXml))
$body.Add((ParagraphXml "1. Protect the existing project before doing anything" "Heading1" -KeepNext))
$body.Add((ListItemXml "Do not work inside the current eatinity-iac directory when creating the separate stack." 1))
$body.Add((ListItemXml "Do not copy eatinity-iac/terraform.tfstate, terraform.tfstate.backup, .terraform, or terraform.tfvars." 2))
$body.Add((ListItemXml "Do not import existing AWS resources into the new state." 3))
$body.Add((ListItemXml "Do not reuse the production API ID, DynamoDB table names, S3 bucket names, Cognito pool ID, CloudFront aliases, or Route 53 records." 4))
$body.Add((ListItemXml "Do not enable manage_public_dns or attach_runtime_policy_to_lab_role during the isolated deployment." 5))
$body.Add((ParagraphXml "Create a safety inventory" "Heading2" -KeepNext))
$body.Add((ParagraphXml "Record the current account ID, current region, production resource names, website URL, API URL, CloudFront distribution ID, Cognito pool ID, and the location of both existing state files. This inventory is evidence that the isolated deployment did not change them."))
$body.Add((CodeXml "aws sts get-caller-identity"))
$body.Add((CodeXml "aws configure get region"))
$body.Add((ParagraphXml "These commands are read-only. Confirm the account is the intended lab/account before proceeding." "Note" -Italic -Shade "FFF4CE"))

$body.Add((ParagraphXml "2. Choose the isolated destination" "Heading1" -KeepNext))
$body.Add((ParagraphXml 'Recommended example: ca-central-1. Any supported region may be used, but all regional services must be checked first. CloudFront and IAM are global services. CloudFront certificates must be in us-east-1 even when the application is elsewhere.'))
$body.Add((ListItemXml "Target region: ca-central-1" -Bullet))
$body.Add((ListItemXml "Environment label: dr" -Bullet))
$body.Add((ListItemXml "State identity: eatinity-dr-ca-central-1" -Bullet))
$body.Add((ListItemXml 'Public access uses only the generated CloudFront hostname. Do not configure an eatinity.ca alias.' -Bullet))

$body.Add((ParagraphXml "3. Create a clean IaC working copy" "Heading1" -KeepNext))
$body.Add((ParagraphXml "Create eatinity-iac-dr beside eatinity-iac. Copy only configuration and documentation files. Keeping it beside eatinity-prod preserves the existing relative Lambda ZIP paths without modifying application files."))
$body.Add((CodeXml "New-Item -ItemType Directory -Path .\\eatinity-iac-dr"))
$body.Add((CodeXml "Copy-Item .\\eatinity-iac\\*.tf .\\eatinity-iac-dr\\"))
$body.Add((CodeXml "Copy-Item .\\eatinity-iac\\.terraform.lock.hcl .\\eatinity-iac-dr\\"))
$body.Add((CodeXml "Copy-Item .\\eatinity-iac\\terraform.tfvars.example .\\eatinity-iac-dr\\"))
$body.Add((ParagraphXml "Never copy any tfstate file, .terraform directory, saved plan, or real terraform.tfvars into the DR directory." "Note" -Bold -Color "8A2D1E" -Shade "FDECEC"))

$body.Add((PageBreakXml))
$body.Add((ParagraphXml "4. Make Cognito greenfield before initialization" "Heading1" -KeepNext))
$body.Add((ParagraphXml "This is the main blocker in the current IaC. cognito.tf uses data aws_cognito_user_pool.current with the production pool ID. A Cognito user pool is regional, so that ID cannot work in ca-central-1."))
$body.Add((ParagraphXml "Required IaC change in the DR copy" "Heading2" -KeepNext))
$body.Add((ListItemXml "Add a create_cognito_resources variable that is true for DR." 1))
$body.Add((ListItemXml "Create a new aws_cognito_user_pool and aws_cognito_user_pool_client when that flag is true." 2))
$body.Add((ListItemXml "Expose local values for the selected pool ID, pool ARN, and client ID." 3))
$body.Add((ListItemXml "Update API Gateway authorizer, Cognito groups, Lambda environment variables, IAM policy, and outputs to use those local values." 4))
$body.Add((ListItemXml "Do not reference the production user pool ID anywhere in the DR configuration." 5))
$body.Add((ParagraphXml 'Do not proceed to plan or apply until this change is complete. Supplying the existing production pool ID in another region will fail. Pointing the DR stack back to us-east-1 would also break the isolation objective.' "Note" -Bold -Shade "FFF4CE"))

$body.Add((ParagraphXml "5. Create unique DR resource names" "Heading1" -KeepNext))
$body.Add((ParagraphXml "Create terraform.tfvars only inside eatinity-iac-dr. Replace the example suffix with a short unique value because S3 bucket names are globally unique."))
$body.Add((CodeXml 'aws_region          = "ca-central-1"'))
$body.Add((CodeXml 'project_name        = "eatinity"'))
$body.Add((CodeXml 'environment         = "dr"'))
$body.Add((CodeXml 'website_bucket_name = "eatinity-dr-ca-<unique>-website"'))
$body.Add((CodeXml 'images_bucket_name  = "eatinity-dr-ca-<unique>-images"'))
$body.Add((CodeXml 'products_table_name   = "EatinityDrProducts"'))
$body.Add((CodeXml 'categories_table_name = "EatinityDrCategories"'))
$body.Add((CodeXml 'orders_table_name     = "EatinityDrOrders"'))
$body.Add((CodeXml 'users_table_name      = "EatinityDrUsers"'))
$body.Add((CodeXml 'audit_table_name      = "EatinityDrAuditLog"'))
$body.Add((CodeXml 'api_name                = "eatinity-dr-api"'))
$body.Add((CodeXml 'sns_topic_name          = "eatinity-dr-order-notifications"'))
$body.Add((CodeXml 'manage_public_dns                  = false'))
$body.Add((CodeXml 'use_custom_domain_certificate     = false'))
$body.Add((CodeXml 'attach_runtime_policy_to_lab_role = false'))
$body.Add((CodeXml 'enable_data_protection            = true'))
$body.Add((CodeXml 'sns_email_subscriptions           = []'))
$body.Add((ParagraphXml "Use Stripe test-mode secrets only. Never commit terraform.tfvars because Terraform state can contain Lambda environment values and other sensitive information." "Note" -Bold -Shade "FFF4CE"))

$body.Add((PageBreakXml))
$body.Add((ParagraphXml "6. Separate Terraform state completely" "Heading1" -KeepNext))
$body.Add((ParagraphXml "The minimum safe approach is a new local state file in eatinity-iac-dr. The stronger approach is a dedicated encrypted S3 backend with a unique key and locking. The backend must not use either existing Eatinity state key."))
$body.Add((ParagraphXml "Example backend identity" "Heading2" -KeepNext))
$body.Add((CodeXml 'bucket       = "<separate-terraform-state-bucket>"'))
$body.Add((CodeXml 'key          = "eatinity/dr/ca-central-1/terraform.tfstate"'))
$body.Add((CodeXml 'region       = "ca-central-1"'))
$body.Add((CodeXml 'encrypt      = true'))
$body.Add((ParagraphXml "Do not create the state bucket in the same configuration that depends on that backend. Bootstrap it separately, or begin with local state and migrate only after review."))

$body.Add((ParagraphXml "7. Review global and cross-region services" "Heading1" -KeepNext))
$body.Add((ListItemXml "CloudFront: creates a separate global distribution. With custom certificate disabled, use its generated cloudfront.net hostname." 1))
$body.Add((ListItemXml "Route 53: keep manage_public_dns false so eatinity.ca and www.eatinity.ca remain attached to production." 2))
$body.Add((ListItemXml "ACM: do not look up or attach the production certificate for the DR distribution." 3))
$body.Add((ListItemXml 'IAM: LabRole is global within the account. Reusing it does not create isolation. Keep the optional policy attachment disabled.' 4))
$body.Add((ListItemXml "SES: identity verification and sandbox status are regional. Use a verified DR sender or temporarily disable email-dependent tests." 5))
$body.Add((ListItemXml "Stripe: create a distinct test webhook endpoint after the new API exists." 6))

$body.Add((ParagraphXml "8. Initialize only the copied directory" "Heading1" -KeepNext))
$body.Add((ParagraphXml "Run Terraform only after the DR copy contains no state and all production identifiers have been removed. Initialization itself does not create AWS resources."))
$body.Add((CodeXml "Set-Location C:\\Marjan\\Eatinity\\eatinity-iac-dr"))
$body.Add((CodeXml "terraform init -reconfigure"))
$body.Add((ParagraphXml "Immediately confirm that the backend/state path is the DR path. If Terraform offers to migrate an existing state unexpectedly, stop and answer no." "Note" -Bold -Shade "FDECEC"))

$body.Add((PageBreakXml))
$body.Add((ParagraphXml "9. Produce and inspect a creation-only plan" "Heading1" -KeepNext))
$body.Add((CodeXml "terraform plan -out=eatinity-dr-create.tfplan"))
$body.Add((ParagraphXml "The plan is acceptable only when every managed infrastructure action is for the isolated stack."))
$body.Add((ListItemXml "Expected: additions for DR S3, DynamoDB, Lambda, API Gateway, Cognito, CloudWatch, SNS, SES configuration, CloudFront, and related policies." -Bullet))
$body.Add((ListItemXml "Forbidden: any update, replacement, import, or destroy involving production names, eatinity.ca DNS, the production Cognito pool, or an existing CloudFront distribution." -Bullet))
$body.Add((ListItemXml "Forbidden: references to either old state lineage or either old AWS account unless that is deliberately the authenticated target account." -Bullet))
$body.Add((ParagraphXml "If the plan contains anything other than the intended creates and safe data-source reads, stop. Do not apply and do not try to fix it by importing production resources." "Note" -Bold -Color "8A2D1E" -Shade "FDECEC"))

$body.Add((ParagraphXml "10. Apply only the reviewed saved plan" "Heading1" -KeepNext))
$body.Add((ParagraphXml "Only after a line-by-line review confirms isolation:"))
$body.Add((CodeXml "terraform apply eatinity-dr-create.tfplan"))
$body.Add((ParagraphXml "Using the saved plan ensures the applied actions are the same actions that were reviewed. Do not run an unsaved terraform apply as the first deployment."))

$body.Add((ParagraphXml "11. Configure and test the isolated stack" "Heading1" -KeepNext))
$body.Add((ListItemXml "Capture the new API endpoint, CloudFront hostname, Cognito pool/client IDs, table names, and bucket names from outputs." 1))
$body.Add((ListItemXml "Create the Stripe test webhook for the new /stripe-webhook endpoint and set only test-mode credentials." 2))
$body.Add((ListItemXml "Seed only the DR product/category tables. Never run seed scripts against production table names." 3))
$body.Add((ListItemXml "Create DR test users in the new Cognito pool." 4))
$body.Add((ListItemXml "Test API endpoints directly before connecting any frontend." 5))
$body.Add((ListItemXml "If a UI is needed, make a separate eatinity-frontend-dr copy and point that copy to the DR API/Cognito values. Do not edit or deploy the production frontend." 6))
$body.Add((ListItemXml "Confirm the original website, API, DynamoDB tables, Cognito users, CloudFront distribution, and DNS records remain unchanged." 7))

$body.Add((PageBreakXml))
$body.Add((ParagraphXml "12. Isolation acceptance checklist" "Heading1" -KeepNext))
$checks = @(
  "Authenticated AWS account ID recorded and approved",
  "Target region differs from production",
  "New directory contains no copied tfstate or .terraform directory",
  "New backend key or new local state confirmed",
  "No import blocks or terraform import commands used",
  "All S3 and DynamoDB names are unique DR names",
  "New regional Cognito pool and client are declared",
  "manage_public_dns is false",
  "use_custom_domain_certificate is false",
  "attach_runtime_policy_to_lab_role is false",
  "Stripe test credentials are used",
  "Plan contains no production update, replace, or destroy",
  "Saved plan reviewed before apply",
  "Production health checked before and after deployment",
  "DR evidence and outputs stored without committing secrets or state"
)
foreach ($check in $checks) { $body.Add((ListItemXml $check -Bullet)) }

$body.Add((ParagraphXml "Optional removal of the DR stack" "Heading1" -KeepNext))
$body.Add((ParagraphXml "If the isolated stack is temporary, destroy it only from eatinity-iac-dr while authenticated to the same approved account and while connected to the DR state. First inspect the destroy plan and confirm every target carries a DR name. Data-protection settings may intentionally prevent table or bucket deletion until explicitly reviewed."))
$body.Add((ParagraphXml "Never run destroy from eatinity-iac or from either existing state. Never disable production deletion protection to clean up the DR exercise." "Note" -Bold -Color "8A2D1E" -Shade "FDECEC"))

$body.Add((ParagraphXml "Final decision" "Heading1" -KeepNext))
$body.Add((ParagraphXml 'Do not deploy the current eatinity-iac unchanged into another region. First create a state-free copy, make Cognito greenfield, assign unique resource names, disable production DNS and certificate integration, and verify a creation-only plan. Following those controls keeps the existing Eatinity project outside the new Terraform state and prevents Terraform from managing it.' -Bold))

$documentXml = @'
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <w:body>
    {{BODY}}
    <w:sectPr>
      <w:footerReference w:type="default" r:id="rId2"/>
      <w:pgSz w:w="12240" w:h="15840"/>
      <w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440" w:header="720" w:footer="720" w:gutter="0"/>
      <w:cols w:space="720"/>
      <w:docGrid w:linePitch="360"/>
    </w:sectPr>
  </w:body>
</w:document>
'@
$documentXml = $documentXml.Replace('{{BODY}}', ($body -join "`n"))

$stylesXml = @'
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:docDefaults><w:rPrDefault><w:rPr><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/><w:sz w:val="22"/><w:szCs w:val="22"/></w:rPr></w:rPrDefault><w:pPrDefault><w:pPr><w:spacing w:after="120" w:line="300" w:lineRule="auto"/></w:pPr></w:pPrDefault></w:docDefaults>
  <w:style w:type="paragraph" w:default="1" w:styleId="Normal"><w:name w:val="Normal"/><w:qFormat/><w:pPr><w:spacing w:before="0" w:after="120" w:line="300" w:lineRule="auto"/></w:pPr><w:rPr><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/><w:sz w:val="22"/></w:rPr></w:style>
  <w:style w:type="paragraph" w:styleId="Title"><w:name w:val="Title"/><w:basedOn w:val="Normal"/><w:next w:val="Subtitle"/><w:qFormat/><w:pPr><w:spacing w:before="0" w:after="120"/><w:keepNext/></w:pPr><w:rPr><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/><w:b/><w:color w:val="1F4D78"/><w:sz w:val="34"/></w:rPr></w:style>
  <w:style w:type="paragraph" w:styleId="Subtitle"><w:name w:val="Subtitle"/><w:basedOn w:val="Normal"/><w:next w:val="Metadata"/><w:qFormat/><w:pPr><w:spacing w:after="240"/></w:pPr><w:rPr><w:color w:val="4F6475"/><w:sz w:val="24"/></w:rPr></w:style>
  <w:style w:type="paragraph" w:styleId="Metadata"><w:name w:val="Metadata"/><w:basedOn w:val="Normal"/><w:next w:val="Normal"/><w:pPr><w:spacing w:after="300"/></w:pPr><w:rPr><w:color w:val="687785"/><w:sz w:val="19"/></w:rPr></w:style>
  <w:style w:type="paragraph" w:styleId="Heading1"><w:name w:val="heading 1"/><w:basedOn w:val="Normal"/><w:next w:val="Normal"/><w:qFormat/><w:pPr><w:keepNext/><w:keepLines/><w:spacing w:before="360" w:after="200"/><w:outlineLvl w:val="0"/></w:pPr><w:rPr><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/><w:b/><w:color w:val="2E74B5"/><w:sz w:val="32"/></w:rPr></w:style>
  <w:style w:type="paragraph" w:styleId="Heading2"><w:name w:val="heading 2"/><w:basedOn w:val="Normal"/><w:next w:val="Normal"/><w:qFormat/><w:pPr><w:keepNext/><w:keepLines/><w:spacing w:before="280" w:after="140"/><w:outlineLvl w:val="1"/></w:pPr><w:rPr><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/><w:b/><w:color w:val="2E74B5"/><w:sz w:val="26"/></w:rPr></w:style>
  <w:style w:type="paragraph" w:styleId="ListParagraph"><w:name w:val="List Paragraph"/><w:basedOn w:val="Normal"/><w:pPr><w:spacing w:after="80" w:line="300" w:lineRule="auto"/><w:ind w:left="540" w:hanging="270"/></w:pPr></w:style>
  <w:style w:type="paragraph" w:styleId="Code"><w:name w:val="Code"/><w:basedOn w:val="Normal"/><w:pPr><w:spacing w:before="40" w:after="40"/><w:ind w:left="240" w:right="240"/><w:shd w:val="clear" w:color="auto" w:fill="F3F6F8"/></w:pPr><w:rPr><w:rFonts w:ascii="Consolas" w:hAnsi="Consolas"/><w:sz w:val="19"/></w:rPr></w:style>
  <w:style w:type="paragraph" w:styleId="Note"><w:name w:val="Note"/><w:basedOn w:val="Normal"/><w:pPr><w:spacing w:before="100" w:after="100"/><w:ind w:left="120" w:right="120"/><w:shd w:val="clear" w:color="auto" w:fill="FFF4CE"/></w:pPr></w:style>
</w:styles>
'@

$numberingXml = @'
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:numbering xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:abstractNum w:abstractNumId="0"><w:multiLevelType w:val="singleLevel"/><w:lvl w:ilvl="0"><w:start w:val="1"/><w:numFmt w:val="decimal"/><w:lvlText w:val="&#x2022;"/><w:lvlJc w:val="left"/><w:pPr><w:tabs><w:tab w:val="num" w:pos="540"/></w:tabs><w:ind w:left="540" w:hanging="270"/></w:pPr></w:lvl></w:abstractNum>
  <w:abstractNum w:abstractNumId="1"><w:multiLevelType w:val="singleLevel"/><w:lvl w:ilvl="0"><w:start w:val="1"/><w:numFmt w:val="bullet"/><w:lvlText w:val="&#x2022;"/><w:lvlJc w:val="left"/><w:pPr><w:tabs><w:tab w:val="num" w:pos="540"/></w:tabs><w:ind w:left="540" w:hanging="270"/></w:pPr><w:rPr><w:rFonts w:ascii="Symbol" w:hAnsi="Symbol"/></w:rPr></w:lvl></w:abstractNum>
  <w:num w:numId="1"><w:abstractNumId w:val="0"/></w:num>
  <w:num w:numId="2"><w:abstractNumId w:val="1"/></w:num>
</w:numbering>
'@

$footerXml = @'
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:ftr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:p><w:pPr><w:jc w:val="center"/><w:spacing w:before="60" w:after="0"/></w:pPr><w:r><w:rPr><w:color w:val="687785"/><w:sz w:val="18"/></w:rPr><w:t>Eatinity Isolated-Region Runbook  |  Page </w:t></w:r><w:fldSimple w:instr="PAGE"><w:r><w:rPr><w:color w:val="687785"/><w:sz w:val="18"/></w:rPr><w:t>1</w:t></w:r></w:fldSimple></w:p>
</w:ftr>
'@

$contentTypes = @'
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
  <Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>
  <Override PartName="/word/numbering.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.numbering+xml"/>
  <Override PartName="/word/footer1.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.footer+xml"/>
  <Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>
  <Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>
</Types>
'@

$rootRels = @'
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>
  <Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/>
</Relationships>
'@

$documentRels = @'
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/footer" Target="footer1.xml"/>
  <Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/numbering" Target="numbering.xml"/>
</Relationships>
'@

$coreXml = @'
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:dcterms="http://purl.org/dc/terms/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <dc:title>Eatinity Isolated-Region Deployment Runbook</dc:title>
  <dc:subject>Safe deployment of a separate Terraform stack in another AWS region</dc:subject>
  <dc:creator>Marjan Haghighi</dc:creator>
  <cp:keywords>Eatinity, Terraform, AWS, disaster recovery, isolated region</cp:keywords>
  <dc:description>Step-by-step safety runbook for deploying Eatinity IaC separately without affecting existing resources.</dc:description>
  <cp:lastModifiedBy>Marjan Haghighi</cp:lastModifiedBy>
  <dcterms:created xsi:type="dcterms:W3CDTF">2026-07-20T00:00:00Z</dcterms:created>
  <dcterms:modified xsi:type="dcterms:W3CDTF">2026-07-20T00:00:00Z</dcterms:modified>
</cp:coreProperties>
'@

$appXml = @'
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties" xmlns:vt="http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes">
  <Application>Microsoft Office Word</Application><AppVersion>16.0000</AppVersion><Company>Eatinity</Company>
</Properties>
'@

$buildDir = Join-Path (Split-Path $OutputPath -Parent) (".docx_build_" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $buildDir, (Join-Path $buildDir "_rels"), (Join-Path $buildDir "word"), (Join-Path $buildDir "word\_rels"), (Join-Path $buildDir "docProps") | Out-Null

[IO.File]::WriteAllText((Join-Path $buildDir "[Content_Types].xml"), $contentTypes, [Text.UTF8Encoding]::new($false))
[IO.File]::WriteAllText((Join-Path $buildDir "_rels\.rels"), $rootRels, [Text.UTF8Encoding]::new($false))
[IO.File]::WriteAllText((Join-Path $buildDir "word\document.xml"), $documentXml, [Text.UTF8Encoding]::new($false))
[IO.File]::WriteAllText((Join-Path $buildDir "word\styles.xml"), $stylesXml, [Text.UTF8Encoding]::new($false))
[IO.File]::WriteAllText((Join-Path $buildDir "word\numbering.xml"), $numberingXml, [Text.UTF8Encoding]::new($false))
[IO.File]::WriteAllText((Join-Path $buildDir "word\footer1.xml"), $footerXml, [Text.UTF8Encoding]::new($false))
[IO.File]::WriteAllText((Join-Path $buildDir "word\_rels\document.xml.rels"), $documentRels, [Text.UTF8Encoding]::new($false))
[IO.File]::WriteAllText((Join-Path $buildDir "docProps\core.xml"), $coreXml, [Text.UTF8Encoding]::new($false))
[IO.File]::WriteAllText((Join-Path $buildDir "docProps\app.xml"), $appXml, [Text.UTF8Encoding]::new($false))

if (Test-Path -LiteralPath $OutputPath) { Remove-Item -LiteralPath $OutputPath -Force }
$stream = [IO.File]::Open($OutputPath, [IO.FileMode]::CreateNew)
try {
  $archive = [IO.Compression.ZipArchive]::new($stream, [IO.Compression.ZipArchiveMode]::Create, $false)
  try {
    Get-ChildItem -LiteralPath $buildDir -File -Recurse | ForEach-Object {
      $relative = $_.FullName.Substring($buildDir.Length + 1).Replace('\', '/')
      $entry = $archive.CreateEntry($relative, [IO.Compression.CompressionLevel]::Optimal)
      $entryStream = $entry.Open()
      $fileStream = [IO.File]::OpenRead($_.FullName)
      try {
        $fileStream.CopyTo($entryStream)
      }
      finally {
        $fileStream.Dispose()
        $entryStream.Dispose()
      }
    }
  }
  finally {
    $archive.Dispose()
  }
}
finally {
  $stream.Dispose()
}

Write-Output $OutputPath
