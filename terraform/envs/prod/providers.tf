provider "aws" {
  region  = local.region
  profile = local.aws_profile

  default_tags {
    tags = local.common_tags
  }
}

# CloudFront requires its ACM certs and CLOUDFRONT-scope WAF ACLs in us-east-1
provider "aws" {
  alias   = "us_east_1"
  region  = "us-east-1"
  profile = local.aws_profile

  default_tags {
    tags = local.common_tags
  }
}

# Management API token, not a project key. Exported as SUPABASE_ACCESS_TOKEN.
provider "supabase" {}

# Exported as VERCEL_API_TOKEN.
provider "vercel" {
  team = local.fireantslab.vercel_team
}

# Exported as CLOUDFLARE_API_TOKEN. DNS edit scope on this one zone is enough.
provider "cloudflare" {}
