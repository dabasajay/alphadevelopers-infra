locals {
  org         = "alphadevelopers"
  env         = "prod"
  aws_profile = "alphadevelopers"

  # Where resume-builder and the shared estate live. FireAnts sits in
  # us-east-1 instead and carries its own region below.
  region = "ap-south-1"

  name_prefix = "${local.org}-${local.env}"

  backup_bucket_name = "${local.org}-${local.env}-db-backups"

  # Must match backend.tf. Denied to the developer group; state holds secrets.
  state_bucket = "${local.org}-tfstate"

  # The identity that applies this repository. ClaudeInfraPolicy grants it
  # exactly the services declared here, in the two regions the account uses.
  infra_user = "claude-user"

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
    domain                = "easyjd.com"
    github_subject_prefix = "repo:alpha-developers-org/resume-builder"
    # Console-managed group; Terraform only attaches the debug policy to it.
    developer_group = "easyjd-developers"
  }

  # Registered by the ansible ssm-agent role. Scopes the console tunnel to this

  # Alarms email here. The subscription needs confirming once from the inbox.
  alert_email       = "se.dabasajay@gmail.com"
  metrics_namespace = "AlphaDevelopers/Datastore"
  datastore_host    = "srv1136595.hstgr.cloud"

  # FireAnts Skills Registry. Next.js on Vercel, Supabase for auth/data/storage,
  # AgentCore for the playground the playground and scans execute in. The domain is
  # registered at Cloudflare, so DNS lives there rather than in Route53.
  fireantslab = {
    domain = "fireantslab.com"
    # Immutable subject: the ids are the account and the repository, and they
    # survive a rename of either, which spelling out owner/repo would not.
    github_subject_prefix = "repo:dabasajay@38384266/fireantslab.com@1372933894"

    # The one service outside ap-south-1: the AgentCore runtimes sit close to
    # the frontend and the database that serve them, rather than with the rest
    # of the estate. The guardrail in services/shared names what may exist here.
    region = "us-east-1"

    # The frontend is hosted outside this account and is not managed here. Its
    # deployments present an OIDC token; these roles trust that and nothing
    # else, so no AWS key is ever stored there.
    frontend_oidc_issuer   = "https://oidc.vercel.com/alphadevelopers"
    frontend_oidc_audience = "https://vercel.com/alphadevelopers"
    # One project, one environment. A preview deployment cannot assume these.
    frontend_oidc_subject     = "owner:alphadevelopers:project:fireantslab-com:environment:production"
    frontend_oidc_thumbprints = ["9e99a48a9960b14926bb7f3b02e22da2b0ab7280"]
  }


  # Provider default_tags applies these everywhere. Activate App, Env and Org
  # as cost allocation tags in Billing to get per-app cost breakdowns.
  common_tags = {
    Org       = local.org
    Env       = local.env
    ManagedBy = "terraform"
  }
}
