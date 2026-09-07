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

# Uncomment once the ECR bootstrap image is pushed. The resume_builder output
# in outputs.tf must be commented in tandem or validate fails.
# module "resume_builder" {
#   source = "../../services/resume-builder"
#
#   providers = {
#     aws           = aws
#     aws.us_east_1 = aws.us_east_1
#   }
#
#   name_prefix       = local.name_prefix
#   config            = local.resume_builder
#   zone_id           = module.shared.zone_ids[local.resume_builder.domain]
#   waf_web_acl_arn   = module.shared.waf_web_acl_arn
#   oidc_provider_arn = module.shared.github_oidc_provider_arn
#   db_host           = local.db_host
#   pgbouncer_port    = local.pgbouncer_port
# }
