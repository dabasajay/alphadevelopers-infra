# What the deployed frontend may do in this account.
#
# It authenticates with an OIDC token from its own platform, so no AWS key is
# ever stored there.
#
# One role, not two. Presigning a browser's websocket and stopping a session
# were split apart at one point, but both would have trusted the same issuer,
# subject and audience — so the frontend could assume either at will and the
# split enforced nothing. Separating them only becomes a control when the
# principals differ, which needs the two paths to deploy as different projects
# or environments. Until then, one role that says what it can do.

resource "aws_iam_openid_connect_provider" "frontend" {
  url             = var.frontend_oidc_issuer
  client_id_list  = [var.frontend_oidc_audience]
  thumbprint_list = var.frontend_oidc_thumbprints
  tags            = local.tags
}

data "aws_iam_policy_document" "frontend" {
  # Presigning proves we issued the URL, never whose conversation it is. The
  # runtime checks an admission grant against stored session state before it
  # admits anyone, so this grants a connection attempt and nothing more.
  statement {
    sid     = "PresignPlaygroundWebsocket"
    actions = ["bedrock-agentcore:InvokeAgentRuntimeWithWebSocketStream"]
    resources = [
      module.playground_runtime.arn,
      "${module.playground_runtime.arn}/*",
    ]
  }

  # Dispatching a scan and ending a session. Both runtimes, because a scan is
  # invoked here and a playground session is stopped here.
  statement {
    sid = "ControlRuntimeSessions"
    actions = [
      "bedrock-agentcore:InvokeAgentRuntime",
      "bedrock-agentcore:StopRuntimeSession",
      "bedrock-agentcore:GetRuntimeSession",
    ]
    resources = [
      module.scan_runtime.arn,
      "${module.scan_runtime.arn}/*",
      module.playground_runtime.arn,
      "${module.playground_runtime.arn}/*",
    ]
  }
}

module "frontend" {
  source = "../../modules/oidc-role"

  name              = "${local.name}-frontend"
  oidc_provider_arn = aws_iam_openid_connect_provider.frontend.arn
  issuer_host       = replace(var.frontend_oidc_issuer, "https://", "")
  policy_name       = "runtime-access"
  policy_json       = data.aws_iam_policy_document.frontend.json
  tags              = local.tags

  # One project, one environment. A preview deployment cannot assume this.
  claims = {
    sub = var.frontend_oidc_subject
    aud = var.frontend_oidc_audience
  }
}

# What CI may do in this account: publish the playground image and roll the
# runtimes onto it. AgentCore pins a digest when a version is created, so a
# push alone changes nothing until the runtime is updated.
data "aws_iam_policy_document" "deploy" {
  statement {
    sid       = "AuthenticateToRegistry"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid = "PublishPlaygroundImage"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:CompleteLayerUpload",
      "ecr:GetDownloadUrlForLayer",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart",
    ]
    resources = [module.playground_image.arn]
  }

  # Update, not create: the runtimes exist in Terraform, and CI only moves them
  # onto the image it just pushed.
  statement {
    sid     = "RollRuntimesOntoIt"
    actions = ["bedrock-agentcore:GetAgentRuntime", "bedrock-agentcore:UpdateAgentRuntime"]
    resources = [
      module.scan_runtime.arn,
      module.playground_runtime.arn,
    ]
  }
}

module "deploy_role" {
  source = "../../modules/github-oidc-role"

  name              = "${local.name}-deploy"
  repository        = var.github_repo
  oidc_provider_arn = var.oidc_provider_arn
  policy_json       = data.aws_iam_policy_document.deploy.json
  tags              = local.tags
}
