data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

# ------------------------------------------------------------------ Playground ---

module "playground_image" {
  source = "../../modules/ecr-repo"

  name = "${local.name}-playground"
  tags = local.tags

  # The deploy workflow pushes over a rolling :latest, which IMMUTABLE rejects.
  image_tag_mutability = "MUTABLE"
  # One image. A rollback redeploys from the tag CI builds, not from ECR history.
  keep_last_images = 1
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
    actions   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents", "logs:DescribeLogStreams"]
    resources = flatten([for g in aws_cloudwatch_log_group.runtime : [g.arn, "${g.arn}:*"]])
  }

  statement {
    sid       = "FindItsLogGroup"
    actions   = ["logs:DescribeLogGroups"]
    resources = ["arn:aws:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:log-group:*"]
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

# AgentCore writes to this exact path and nowhere else, so the name is not ours to choose.
resource "aws_cloudwatch_log_group" "runtime" {
  for_each = {
    scan       = module.scan_runtime.id
    playground = module.playground_runtime.id
  }

  name              = "/aws/bedrock-agentcore/runtimes/${each.value}-DEFAULT"
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
}

module "playground_runtime" {
  source = "../../modules/agentcore-runtime"

  name          = "fireants_playground"
  description   = "Interactive playground sessions over websockets."
  role_arn      = aws_iam_role.runtime.arn
  container_uri = "${module.playground_image.repository_url}:latest"

  # The grant a session redeems, and the origin it redeems it against.
  request_header_allowlist = [
    "X-Amzn-Bedrock-AgentCore-Runtime-Custom-Fireants-Grant",
    "X-Amzn-Bedrock-AgentCore-Runtime-Custom-Fireants-Origin",
  ]
}
