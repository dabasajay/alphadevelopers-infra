locals {
  org         = "alphadevelopers"
  env         = "prod"
  aws_profile = "alphadevelopers"

  region = "ap-south-1"

  name_prefix = "${local.org}-${local.env}"

  # Hostinger VM. Both this name and its IP are in the server cert SAN.
  db_host = "srv1136595.hstgr.cloud"

  # Non-standard and below the 32768 ephemeral range, so the listener cannot
  # lose its port to an outbound connection after a reboot.
  pgbouncer_port = 24312

  backup_bucket_name = "${local.org}-${local.env}-db-backups"

  # Looked up, not created: these zones hold live NS records.
  route53_zone_names = ["easyjd.com"]

  # Shared CLOUDFRONT web ACL, ~$8/month across every distribution. While off,
  # Lambda reserved concurrency is the only bill cap and there is no edge rate
  # limiting; per-route limiting is the app's job in Redis either way.
  waf_enabled    = false
  waf_rate_limit = 2000

  # AWSManagedRulesCommonRuleSet, Count mode only. Its SizeRestrictions_BODY
  # rule blocks bodies over 8KB so be careful.
  waf_enable_common_rules = false

  # Optional fields (memory, timeouts, reserved concurrency, log retention)
  # default in services/resume-builder/variables.tf.
  resume_builder = {
    domain      = "easyjd.com"
    github_repo = "dabasajay/resume-builder"
    redis_port  = 24320
    pg_database = "resume_db"
    pg_role     = "resume_app"
  }

  # Provider default_tags applies these everywhere. Activate App, Env and Org
  # as cost allocation tags in Billing to get per-app cost breakdowns.
  common_tags = {
    Org       = local.org
    Env       = local.env
    ManagedBy = "terraform"
  }
}
