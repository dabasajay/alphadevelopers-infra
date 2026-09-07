module "cert" {
  source = "../../modules/acm-cert"

  providers = {
    aws = aws.us_east_1
  }

  domain_name               = var.domain
  subject_alternative_names = ["www.${var.domain}"]
  zone_id                   = var.zone_id
  tags                      = local.tags
}

module "ecr" {
  source = "../../modules/ecr-repo"

  name             = local.name
  keep_last_images = 1
  tags             = local.tags

  # Deploys push over a rolling :latest tag, which IMMUTABLE would reject.
  image_tag_mutability = "MUTABLE"
}

module "spa_bucket" {
  source = "../../modules/s3-bucket"

  name = "${local.name}-spa"
  # The CloudFront OAC policy is a bucket policy, so the policy block must stay open
  block_public_policy = false
  tags                = local.tags
}

module "pdf_bucket" {
  source = "../../modules/s3-bucket"

  name = "${local.name}-pdfs"
  tags = local.tags
}

data "aws_iam_policy_document" "lambda" {
  statement {
    sid       = "PublishedResumePdfs"
    actions   = ["s3:PutObject", "s3:GetObject", "s3:DeleteObject"]
    resources = ["${module.pdf_bucket.arn}/*"]
  }
}

module "api" {
  source = "../../modules/lambda-container"

  name = "${local.name}-api"
  # Rolling tag. CI pushes over it and calls UpdateFunctionCode; Terraform
  # seeds it on create and ignores it after.
  image_uri = "${module.ecr.repository_url}:latest"
  # Only ~190MB is ever used; this is bought for CPU, which Lambda scales with
  # memory. Cold start init was averaging 3.7s against 168ms of actual work,
  # and init is CPU bound. At a few thousand invocations a month the extra
  # cost is under two cents.
  memory_mb = 2048
  timeout   = 30

  # Caps both the bill and the pgbouncer server connections, which are pooled at
  # 20 for this app. Excess invocations are throttled, not queued.
  reserved_concurrency = 20

  log_retention_days  = 7
  enable_function_url = true
  policy_json         = data.aws_iam_policy_document.lambda.json
  tags                = local.tags
}

module "cdn" {
  source = "../../modules/cloudfront-spa-api"

  name                            = local.name
  aliases                         = [var.domain, "www.${var.domain}"]
  acm_certificate_arn             = module.cert.arn
  spa_bucket_id                   = module.spa_bucket.id
  spa_bucket_arn                  = module.spa_bucket.arn
  spa_bucket_regional_domain_name = module.spa_bucket.regional_domain_name
  api_function_name               = module.api.function_name
  api_origin_domain               = module.api.function_url_domain
  web_acl_arn                     = var.waf_web_acl_arn
  tags                            = local.tags
}

module "dns" {
  source = "../../modules/route53-record"

  zone_id      = var.zone_id
  names        = [var.domain, "www.${var.domain}"]
  alias_target = module.cdn.domain_name
}

data "aws_iam_policy_document" "deploy" {
  statement {
    sid       = "EcrAuth"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid = "EcrPush"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:CompleteLayerUpload",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart",
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer",
    ]
    resources = [module.ecr.arn]
  }

  statement {
    sid = "UpdateFunction"
    actions = [
      "lambda:UpdateFunctionCode",
      "lambda:GetFunction",
      # Distinct from GetFunction, and what the function-updated waiter polls.
      "lambda:GetFunctionConfiguration",
      "lambda:PublishVersion",
    ]
    resources = [module.api.function_arn]
  }

  # Migrations run as a direct invoke of the API function, so no publicly
  # reachable route can alter the schema.
  statement {
    sid       = "RunMigrations"
    actions   = ["lambda:InvokeFunction"]
    resources = [module.api.function_arn]
  }

  statement {
    sid       = "SyncSpa"
    actions   = ["s3:PutObject", "s3:DeleteObject", "s3:ListBucket", "s3:GetObject"]
    resources = [module.spa_bucket.arn, "${module.spa_bucket.arn}/*"]
  }

  statement {
    sid       = "Invalidate"
    actions   = ["cloudfront:CreateInvalidation", "cloudfront:GetInvalidation"]
    resources = [module.cdn.distribution_arn]
  }
}

module "deploy_role" {
  source = "../../modules/github-oidc-role"

  name              = "${local.name}-deploy"
  repository        = var.github_repo
  oidc_provider_arn = var.oidc_provider_arn
  policy_json       = data.aws_iam_policy_document.deploy.json
  tags              = local.tags
}

# Hand debugging for the people who run this app: its own buckets, its function
# config and logs, its CDN and image. Deploys stay with the OIDC role above and
# infrastructure stays with Terraform, so neither is granted here.
data "aws_iam_policy_document" "developer_debug" {
  statement {
    sid = "AppBucketObjects"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:GetObjectVersion",
      "s3:PutObjectTagging",
      "s3:AbortMultipartUpload",
    ]
    resources = ["${module.spa_bucket.arn}/*", "${module.pdf_bucket.arn}/*"]
  }

  statement {
    sid       = "AppBucketList"
    actions   = ["s3:ListBucket", "s3:ListBucketVersions", "s3:GetBucketLocation"]
    resources = [module.spa_bucket.arn, module.pdf_bucket.arn]
  }

  # UpdateFunctionCode is absent on purpose: code ships through CI only.
  statement {
    sid = "FunctionConfigAndInvoke"
    actions = [
      "lambda:GetFunction",
      "lambda:GetFunctionConfiguration",
      "lambda:GetFunctionUrlConfig",
      "lambda:UpdateFunctionConfiguration",
      "lambda:InvokeFunction",
      "lambda:ListVersionsByFunction",
    ]
    resources = [module.api.function_arn]
  }

  statement {
    sid = "FunctionLogs"
    actions = [
      "logs:GetLogEvents",
      "logs:FilterLogEvents",
      "logs:DescribeLogStreams",
      "logs:StartQuery",
      "logs:StopQuery",
      "logs:GetQueryResults",
    ]
    resources = [module.api.log_group_arn, "${module.api.log_group_arn}:*"]
  }

  # Logs Insights refuses to run without these, and neither accepts a resource.
  statement {
    sid       = "LogsInsightsNeedsAccountScope"
    actions   = ["logs:DescribeQueries", "logs:DescribeLogGroups"]
    resources = ["*"]
  }

  statement {
    sid       = "CdnInvalidation"
    actions   = ["cloudfront:CreateInvalidation", "cloudfront:GetInvalidation", "cloudfront:ListInvalidations"]
    resources = [module.cdn.distribution_arn]
  }

  statement {
    sid = "PullTheAppImage"
    actions = [
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchCheckLayerAvailability",
      "ecr:DescribeImages",
    ]
    resources = [module.ecr.arn]
  }

  statement {
    sid       = "EcrLoginIsAccountScoped"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  # The group also carries ReadOnlyAccess, which grants s3:GetObject on every
  # bucket. Terraform state holds the backup IAM secret in plaintext, and old
  # versions keep it even after the bucket is re-encrypted, so deny the whole
  # bucket outright. A Deny beats any Allow, including a future broad one.
  statement {
    sid    = "NeverReadTerraformState"
    effect = "Deny"
    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:ListBucket",
      "s3:ListBucketVersions",
    ]
    resources = [var.tfstate_bucket_arn, "${var.tfstate_bucket_arn}/*"]
  }
}

resource "aws_iam_policy" "developer_debug" {
  count = var.developer_group == null ? 0 : 1
  name  = "easyjd-resume-builder-debug"
  # Immutable in IAM: editing it forces a replacement of the policy.
  description = "Debug and experiment on the easyjd.com app: its two buckets, its Lambda config and invocation, its logs, CDN invalidation and image pulls. No infrastructure changes, no Terraform state, no other app."
  policy      = data.aws_iam_policy_document.developer_debug.json
  tags        = local.tags
}

# The group itself is console-managed; only this attachment is Terraform's.
resource "aws_iam_group_policy_attachment" "developer_debug" {
  count      = var.developer_group == null ? 0 : 1
  group      = var.developer_group
  policy_arn = aws_iam_policy.developer_debug[0].arn
}

resource "aws_cloudwatch_metric_alarm" "api_errors" {
  alarm_name          = "${local.name}-api-errors"
  alarm_description   = "The API function is returning errors."
  namespace           = "AWS/Lambda"
  metric_name         = "Errors"
  dimensions          = { FunctionName = module.api.function_name }
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 5
  comparison_operator = "GreaterThanThreshold"
  # No invocations means no errors, which is genuinely healthy here.
  treat_missing_data = "notBreaching"

  alarm_actions = [var.alerts_topic_arn]
  ok_actions    = [var.alerts_topic_arn]
  tags          = local.tags
}

# Reserved concurrency is 20, so throttling is now reachable and otherwise silent.
resource "aws_cloudwatch_metric_alarm" "api_throttles" {
  alarm_name          = "${local.name}-api-throttles"
  alarm_description   = "The API function is being throttled against its reserved concurrency."
  namespace           = "AWS/Lambda"
  metric_name         = "Throttles"
  dimensions          = { FunctionName = module.api.function_name }
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  alarm_actions = [var.alerts_topic_arn]
  ok_actions    = [var.alerts_topic_arn]
  tags          = local.tags
}

# Catches origin and OAC failures that never reach the function, so Lambda's own
# error metric would stay flat.
resource "aws_cloudwatch_metric_alarm" "cdn_5xx" {
  provider            = aws.us_east_1
  alarm_name          = "${local.name}-cdn-5xx"
  alarm_description   = "CloudFront is serving 5xx for more than 5% of requests."
  namespace           = "AWS/CloudFront"
  metric_name         = "5xxErrorRate"
  dimensions          = { DistributionId = module.cdn.distribution_id, Region = "Global" }
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 2
  threshold           = 5
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  alarm_actions = [var.alerts_edge_topic_arn]
  ok_actions    = [var.alerts_edge_topic_arn]
  tags          = local.tags
}
