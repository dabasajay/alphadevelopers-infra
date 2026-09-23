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
  alert_email             = local.alert_email
  metrics_namespace       = local.metrics_namespace
  datastore_host          = local.datastore_host
  developer_group         = local.resume_builder.developer_group
  infra_user              = local.infra_user
  state_bucket            = local.state_bucket
  ssm_secret_prefix       = local.ssm_secret_prefix
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


  tfstate_bucket_arn    = "arn:aws:s3:::${local.state_bucket}"
  alerts_topic_arn      = module.shared.alerts_topic_arn
  alerts_edge_topic_arn = module.shared.alerts_edge_topic_arn
}

# The one service outside ap-south-1. It is handed a provider already pointed at
# its own region rather than a region variable, so nothing inside it can drift
# from where it actually runs.
module "fireantslab" {
  source = "../../services/fireantslab"

  providers = {
    aws = aws.fireantslab
  }

  name_prefix = local.name_prefix
  domain      = local.fireantslab.domain

  github_repo       = local.fireantslab.github_repo
  oidc_provider_arn = module.shared.github_oidc_provider_arn

  frontend_oidc_issuer      = local.fireantslab.frontend_oidc_issuer
  frontend_oidc_audience    = local.fireantslab.frontend_oidc_audience
  frontend_oidc_subject     = local.fireantslab.frontend_oidc_subject
  frontend_oidc_thumbprints = local.fireantslab.frontend_oidc_thumbprints
}
