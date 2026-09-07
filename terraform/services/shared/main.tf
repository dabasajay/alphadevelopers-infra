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

  # The host publishes backup age, cert expiry and disk use. PutMetricData takes
  # no resource, so the namespace condition is the only scoping available.
  statement {
    sid       = "PublishHostMetrics"
    actions   = ["cloudwatch:PutMetricData"]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "cloudwatch:namespace"
      values   = [var.metrics_namespace]
    }
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

resource "aws_sns_topic" "alerts" {
  name = "${var.name_prefix}-alerts"
  tags = { App = "shared" }
}

# Terraform cannot confirm this; AWS emails a link that has to be clicked once.
resource "aws_sns_topic_subscription" "alerts_email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# The host publishes these hourly. Missing data is breaching on all three so a
# dead or unreachable host alerts by going quiet rather than looking healthy.
locals {
  datastore_alarms = {
    backup-age = {
      metric      = "BackupAgeHours"
      threshold   = 26
      comparison  = "GreaterThanThreshold"
      description = "No pgBackRest backup completed in the last 26 hours."
    }
    cert-expiry = {
      metric      = "DaysUntilCertExpiry"
      threshold   = 30
      comparison  = "LessThanThreshold"
      description = "A database client certificate expires within 30 days. Renewing it means rewriting the Lambda env."
    }
    disk-used = {
      metric      = "DiskUsedPercent"
      threshold   = 80
      comparison  = "GreaterThanThreshold"
      description = "Root filesystem above 80% on the datastore host."
    }
  }
}

resource "aws_cloudwatch_metric_alarm" "datastore" {
  for_each = local.datastore_alarms

  alarm_name          = "${var.name_prefix}-${each.key}"
  alarm_description   = each.value.description
  namespace           = var.metrics_namespace
  metric_name         = each.value.metric
  dimensions          = { Host = var.datastore_host }
  statistic           = "Maximum"
  period              = 3600
  evaluation_periods  = 2
  threshold           = each.value.threshold
  comparison_operator = each.value.comparison
  treat_missing_data  = "breaching"

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]
  tags          = { App = "shared" }
}

# CloudFront only publishes metrics in us-east-1, and an alarm can only notify a
# topic in its own region, so the edge alarms need a topic of their own.
resource "aws_sns_topic" "alerts_edge" {
  provider = aws.us_east_1
  name     = "${var.name_prefix}-alerts-edge"
  tags     = { App = "shared" }
}

resource "aws_sns_topic_subscription" "alerts_edge_email" {
  provider  = aws.us_east_1
  topic_arn = aws_sns_topic.alerts_edge.arn
  protocol  = "email"
  endpoint  = var.alert_email
}
