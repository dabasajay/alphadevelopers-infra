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
