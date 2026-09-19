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

# FireAnts sits outside the estate's region on purpose, so it gets its own
# provider rather than borrowing the CloudFront one that happens to share a
# region today. Named for the app, so moving it is a one-line change here.
provider "aws" {
  alias   = "fireantslab"
  region  = local.fireantslab.region
  profile = local.aws_profile

  default_tags {
    tags = local.common_tags
  }
}
