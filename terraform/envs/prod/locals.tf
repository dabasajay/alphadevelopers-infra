locals {
  org         = "alphadevelopers"
  env         = "prod"
  aws_profile = "alphadevelopers"

  region = "ap-south-1"

  name_prefix = "${local.org}-${local.env}"

  backup_bucket_name = "${local.org}-${local.env}-db-backups"

  # Must match backend.tf. Denied to the developer group; state holds secrets.
  state_bucket = "${local.org}-tfstate"

  # Console-managed group carrying the region and destructive-action guardrail.
  region_locked_group = "region-locked-non-destructive-access"

  # Ansible mirrors its unrecoverable secrets here. Denied to developers.
  ssm_secret_prefix = "/alphadevelopers/prod/ansible"

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

  # Datastore host, ports and credentials are console-managed Lambda env vars,
  # so they are not Terraform's concern; see the ansible layer.
  resume_builder = {
    domain      = "easyjd.com"
    github_repo = "alpha-developers-org/resume-builder"
    # Console-managed group; Terraform only attaches the debug policy to it.
    developer_group = "easyjd-developers"
    # Loopback port pgweb is published on. Must match ansible group_vars.
    console_port = 8081
  }

  # Registered by the ansible ssm-agent role. Scopes the console tunnel to this
  # one host so a second datastore host later cannot be reached by accident.
  datastore_instance_id = "mi-07483ed47d77f9a1a"

  # Alarms email here. The subscription needs confirming once from the inbox.
  alert_email       = "se.dabasajay@gmail.com"
  metrics_namespace = "AlphaDevelopers/Datastore"
  datastore_host    = "srv1136595.hstgr.cloud"

  # Provider default_tags applies these everywhere. Activate App, Env and Org
  # as cost allocation tags in Billing to get per-app cost breakdowns.
  common_tags = {
    Org       = local.org
    Env       = local.env
    ManagedBy = "terraform"
  }
}
