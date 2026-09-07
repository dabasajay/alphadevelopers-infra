module "cert" {
  source = "../../modules/acm-cert"

  providers = {
    aws = aws.us_east_1
  }

  domain_name               = var.config.domain
  subject_alternative_names = ["www.${var.config.domain}"]
  zone_id                   = var.zone_id
  tags                      = local.tags
}

module "ecr" {
  source = "../../modules/ecr-repo"

  name             = local.name
  keep_last_images = 5
  tags             = local.tags
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

  name       = "${local.name}-pdfs"
  versioning = true
  tags       = local.tags

  lifecycle_rules = [{
    id                         = "expire-old-versions"
    noncurrent_expiration_days = 30
  }]
}

# Placeholders only. Ansible writes the real values, so no database or Redis
# secret ever passes through Terraform or lands in state.
module "secrets" {
  source = "../../modules/ssm-parameter"

  prefix = local.ssm_prefix
  tags   = local.tags

  parameters = {
    "db-password"          = { description = "Postgres role password for ${var.config.pg_role}" }
    "db-client-cert"       = { description = "mTLS client certificate for pgbouncer" }
    "db-client-key"        = { description = "mTLS client private key" }
    "db-server-ca"         = { description = "Private CA that signed the VM server cert" }
    "redis-password"       = { description = "Redis ACL password" }
    "jwt-secret-key"       = { description = "Session and access token signing key" }
    "google-client-id"     = { description = "Google OAuth client id", secure = false }
    "google-client-secret" = { description = "Google OAuth client secret" }
  }
}

data "aws_iam_policy_document" "lambda" {
  statement {
    sid       = "ReadOwnSecrets"
    actions   = ["ssm:GetParameter", "ssm:GetParameters", "ssm:GetParametersByPath"]
    resources = ["arn:aws:ssm:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:parameter${local.ssm_prefix}/*"]
  }

  statement {
    sid       = "DecryptSecrets"
    actions   = ["kms:Decrypt"]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["ssm.${data.aws_region.current.region}.amazonaws.com"]
    }
  }

  statement {
    sid       = "PublishedResumePdfs"
    actions   = ["s3:PutObject", "s3:GetObject"]
    resources = ["${module.pdf_bucket.arn}/*"]
  }
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

module "api" {
  source = "../../modules/lambda-container"

  name                 = "${local.name}-api"
  image_uri            = "${module.ecr.repository_url}:${local.image_tag}"
  memory_mb            = var.config.lambda_memory_mb
  timeout              = var.config.lambda_timeout
  reserved_concurrency = var.config.lambda_reserved_conc
  log_retention_days   = var.config.log_retention_days
  enable_function_url  = true
  policy_json          = data.aws_iam_policy_document.lambda.json
  tags                 = local.tags

  environment = {
    SSM_PREFIX                  = local.ssm_prefix
    DB_HOST                     = var.db_host
    DB_PORT                     = tostring(var.pgbouncer_port)
    DB_NAME                     = var.config.pg_database
    DB_USER                     = var.config.pg_role
    DB_SSLMODE                  = "verify-full"
    REDIS_HOST                  = var.db_host
    REDIS_PORT                  = tostring(var.config.redis_port)
    S3_BUCKET_NAME              = module.pdf_bucket.id
    AWS_REGION_NAME             = data.aws_region.current.region
    CORS_ORIGINS                = "https://${var.config.domain}"
    FRONTEND_REDIRECT_URL       = "https://${var.config.domain}/callback"
    GOOGLE_CALLBACK_URI         = "${local.api_base_url}/auth/google/callback"
    ACCESS_TOKEN_EXPIRE_MINUTES = tostring(var.config.access_token_min)
    ENCODE_ALGORITHM            = "HS256"
    IS_PRODUCTION               = "True"
  }
}

# Same image, different entrypoint. Runs alembic from inside AWS so the
# database never needs to accept connections from a CI runner.
module "migrate" {
  source = "../../modules/lambda-container"

  name               = "${local.name}-migrate"
  image_uri          = "${module.ecr.repository_url}:${local.image_tag}"
  image_command      = ["app.lambda_migrate.handler"]
  memory_mb          = var.config.migrate_memory_mb
  timeout            = var.config.migrate_timeout
  log_retention_days = var.config.log_retention_days
  policy_json        = data.aws_iam_policy_document.lambda.json
  tags               = local.tags

  environment = {
    SSM_PREFIX = local.ssm_prefix
    DB_HOST    = var.db_host
    DB_PORT    = tostring(var.pgbouncer_port)
    DB_NAME    = var.config.pg_database
    DB_USER    = var.config.pg_role
    DB_SSLMODE = "verify-full"
  }
}

module "cdn" {
  source = "../../modules/cloudfront-spa-api"

  name                            = local.name
  aliases                         = [var.config.domain, "www.${var.config.domain}"]
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
  names        = [var.config.domain, "www.${var.config.domain}"]
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
    sid       = "UpdateFunctions"
    actions   = ["lambda:UpdateFunctionCode", "lambda:GetFunction", "lambda:PublishVersion"]
    resources = [module.api.function_arn, module.migrate.function_arn]
  }

  statement {
    sid       = "RunMigrations"
    actions   = ["lambda:InvokeFunction"]
    resources = [module.migrate.function_arn]
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
  repository        = var.config.github_repo
  oidc_provider_arn = var.oidc_provider_arn
  policy_json       = data.aws_iam_policy_document.deploy.json
  tags              = local.tags
}
