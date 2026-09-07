# Zones are looked up, not created: they already hold live NS records and
# recreating them would issue new nameservers.
data "aws_route53_zone" "this" {
  for_each     = toset(var.zone_names)
  name         = each.value
  private_zone = false
}

module "waf" {
  source = "../../modules/waf-web-acl"
  count  = var.waf_enabled ? 1 : 0

  providers = {
    aws = aws.us_east_1
  }

  name                = "${var.name_prefix}-shared"
  rate_limit          = var.waf_rate_limit
  enable_common_rules = var.waf_enable_common_rules
  tags                = { App = "shared" }
}

module "backup_bucket" {
  source = "../../modules/s3-bucket"

  name       = var.backup_bucket_name
  versioning = true
  tags       = { App = "shared" }

  # Immutability floor. Shorter than the noncurrent expiry below, or lifecycle
  # could never reclaim a version pgBackRest has retired.
  object_lock_days = 7

  # pgBackRest keeps the last 3 fulls, so retention is a count and only it can
  # enforce it. No expiration on current versions on purpose: an age rule would
  # delete the last remaining full if backups ever stopped running.
  lifecycle_rules = [{
    id                         = "reclaim-expired-backups"
    noncurrent_expiration_days = 14
  }]
}

# The VM's credentials for pgBackRest. DeleteObject is granted so `pgbackrest
# expire` can enforce the 3-full retention, but on a versioned bucket that only
# writes a delete marker. DeleteObjectVersion is never granted to anyone, so the
# underlying versions stay immutable under Object Lock compliance mode and a
# compromised VM still cannot destroy its own backups.
data "aws_iam_policy_document" "backup_writer" {
  statement {
    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:DeleteObject",
      "s3:ListBucket",
      "s3:ListBucketVersions",
      "s3:AbortMultipartUpload",
      "s3:ListBucketMultipartUploads",
      "s3:ListMultipartUploadParts",
    ]
    resources = [
      module.backup_bucket.arn,
      "${module.backup_bucket.arn}/*",
    ]
  }
}

resource "aws_iam_user" "backup" {
  name = "${var.name_prefix}-db-backup"
  tags = { App = "shared" }
}

resource "aws_iam_user_policy" "backup" {
  name   = "backup-writer"
  user   = aws_iam_user.backup.name
  policy = data.aws_iam_policy_document.backup_writer.json
}

resource "aws_iam_access_key" "backup" {
  user = aws_iam_user.backup.name
}

# One provider per account. App deploy roles federate against it.
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
  tags            = { App = "shared" }
}
