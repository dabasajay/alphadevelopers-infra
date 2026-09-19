data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

# ------------------------------------------------------------------ Playground ---

module "playground_image" {
  source = "../../modules/ecr-repo"

  name = "${local.name}-playground"
  tags = local.tags

  # The deploy workflow pushes over a rolling :latest, which IMMUTABLE rejects.
  image_tag_mutability = "MUTABLE"
  keep_last_images     = 10
}

# What the playground itself runs as.
#
# Code inside a microVM can read this role's credentials, so it carries nothing
# that would matter if it leaked: no registry, no publication, no database, no
# access to another session. Pulling its own image, writing its own logs and
# calling a model is the whole of it.
data "aws_iam_policy_document" "runtime_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["bedrock-agentcore.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = ["arn:aws:bedrock-agentcore:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:*"]
    }
  }
}

resource "aws_iam_role" "runtime" {
  name               = "${local.name}-runtime"
  assume_role_policy = data.aws_iam_policy_document.runtime_assume.json
  tags               = local.tags
}

data "aws_iam_policy_document" "runtime" {
  statement {
    sid       = "EcrLoginIsAccountScoped"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid       = "PullOnlyItsOwnImage"
    actions   = ["ecr:BatchGetImage", "ecr:GetDownloadUrlForLayer"]
    resources = [module.playground_image.arn]
  }

  statement {
    sid       = "WriteOnlyItsOwnLogs"
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents", "logs:DescribeLogStreams"]
    resources = ["${aws_cloudwatch_log_group.runtime.arn}:*"]
  }

  statement {
    sid       = "CallAModel"
    actions   = ["bedrock:InvokeModel", "bedrock:InvokeModelWithResponseStream"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "runtime" {
  name   = "execution"
  role   = aws_iam_role.runtime.id
  policy = data.aws_iam_policy_document.runtime.json
}

resource "aws_cloudwatch_log_group" "runtime" {
  name              = "/aws/bedrock-agentcore/${local.name}"
  retention_in_days = 30
  tags              = local.tags
}

# Two runtimes, not one. A scan is an unattended judgement whose result gates
# publication; a playground turn is someone poking at a skill. Sharing compute
# between them would let a playground session influence a verdict.
module "scan_runtime" {
  source = "../../modules/agentcore-runtime"

  name          = "fireants_scan"
  description   = "Detonation scans. Its output is evidence, never a verdict."
  role_arn      = aws_iam_role.runtime.arn
  container_uri = "${module.playground_image.repository_url}:latest"

  environment = {
    FIREANTS_ROLE     = "scan"
    FIREANTS_SITE_URL = "https://${var.domain}"
  }
}

module "playground_runtime" {
  source = "../../modules/agentcore-runtime"

  name          = "fireants_playground"
  description   = "Interactive playground sessions over websockets."
  role_arn      = aws_iam_role.runtime.arn
  container_uri = "${module.playground_image.repository_url}:latest"

  # No admission secret yet. A signed URL alone admits nobody, so whatever
  # replaces it still has to be verified inside the runtime against stored
  # session state rather than trusted from the connection.
  environment = {
    FIREANTS_ROLE     = "playground"
    FIREANTS_SITE_URL = "https://${var.domain}"
  }
}
