module "shared" {
  source = "../../services/shared"

  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }

  name_prefix             = local.name_prefix
  zone_names              = local.route53_zone_names
  backup_bucket_name      = local.backup_bucket_name
  waf_enabled             = local.waf_enabled
  waf_rate_limit          = local.waf_rate_limit
  waf_enable_common_rules = local.waf_enable_common_rules
}

# Apply only after an initial :latest image is pushed; a container-image Lambda
# cannot be created against an empty repository.
module "resume_builder" {
  source = "../../services/resume-builder"

  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }

  name_prefix       = local.name_prefix
  domain            = local.resume_builder.domain
  github_repo       = local.resume_builder.github_repo
  zone_id           = module.shared.zone_ids[local.resume_builder.domain]
  waf_web_acl_arn   = module.shared.waf_web_acl_arn
  oidc_provider_arn = module.shared.github_oidc_provider_arn
  developer_group   = local.resume_builder.developer_group
}
