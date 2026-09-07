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
  memory_mb = 1024
  timeout   = 30

  # Bounds both the bill and the pgbouncer connection count.
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
    sid       = "UpdateFunction"
    actions   = ["lambda:UpdateFunctionCode", "lambda:GetFunction", "lambda:PublishVersion"]
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
