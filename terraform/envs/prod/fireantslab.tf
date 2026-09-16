# FireAnts Skills Registry.
#
#   Cloudflare DNS ──► Vercel (Next.js: site, platform API, MCP, presigning)
#                        │
#                        ├── Supabase ── Auth · Postgres · private Storage
#                        │
#                        └── presigns ──► AgentCore runtime (sandbox execution)
#                                            ▲
#                        browser ────────────┘  direct websocket, 60s to connect
#
# Playground streams never transit Vercel. Next.js decides who may connect and
# signs a short-lived URL for one session; the bytes go browser-to-runtime.

data "aws_caller_identity" "current" {}

# ---------------------------------------------------------------- Supabase ---

resource "random_password" "fireantslab_db" {
  length  = 40
  special = false
}

# Signs the admission grant that names the conversation a connection may touch.
# Both Vercel and the runtime hold it; nothing else does.
resource "random_password" "fireantslab_admission" {
  length  = 48
  special = false
}

resource "supabase_project" "fireantslab" {
  organization_id   = local.fireantslab.supabase_org_id
  name              = "${local.name_prefix}-fireantslab"
  region            = local.fireantslab.supabase_region
  database_password = random_password.fireantslab_db.result

  lifecycle {
    # Recreating a project would destroy every account and archive in it.
    prevent_destroy = true
    ignore_changes  = [database_password]
  }
}

resource "supabase_settings" "fireantslab" {
  project_ref = supabase_project.fireantslab.id

  auth = jsonencode({
    site_url = "https://${local.fireantslab.domain}"
    uri_allow_list = join(",", [
      "https://${local.fireantslab.domain}/auth/callback",
      "https://www.${local.fireantslab.domain}/auth/callback",
    ])
    # Public registry access is a paid subscription, but the account comes
    # first: signup is open and entitlement is checked per request.
    disable_signup                        = false
    jwt_exp                               = 3600
    refresh_token_rotation_enabled        = true
    security_refresh_token_reuse_interval = 10

    # No passwords in production. Hiding the form would not be enough: the
    # endpoint stays reachable, so the provider itself is off and a password
    # grant is refused by Auth rather than by the UI.
    external_email_enabled = false

    external_google_enabled = true
    external_github_enabled = true
  })

  api = jsonencode({
    # No application table is reachable over PostgREST by design; the platform
    # API owns every read. Exposing the schema still costs nothing because RLS
    # denies by default.
    db_schema            = "public,graphql_public"
    db_extra_search_path = "public,extensions"
    max_rows             = 1000
  })

  storage = jsonencode({
    # One skill archive. Publishing is bounded well below this.
    fileSizeLimit = 26214400
  })
}

# --------------------------------------------------------------- AgentCore ---

# The pinned execution image. Mutable tag: the deploy workflow owns what
# :latest points at once the runtime exists.
resource "aws_ecr_repository" "fireantslab_sandbox" {
  name                 = "${local.name_prefix}-fireantslab-sandbox"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_lifecycle_policy" "fireantslab_sandbox" {
  repository = aws_ecr_repository.fireantslab_sandbox.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep the last 10 images"
      selection    = { tagStatus = "any", countType = "imageCountMoreThan", countNumber = 10 }
      action       = { type = "expire" }
    }]
  })
}

# What the sandbox itself runs as.
#
# Code inside a microVM can read this role's credentials, so it carries nothing
# that would matter if it leaked: no registry, no publication, no Supabase, no
# access to another session. Pulling its own image, writing its own logs and
# calling a model is the whole of it.
resource "aws_iam_role" "fireantslab_runtime" {
  name = "${local.name_prefix}-fireantslab-runtime"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "bedrock-agentcore.amazonaws.com" }
      Action    = "sts:AssumeRole"
      Condition = {
        StringEquals = { "aws:SourceAccount" = data.aws_caller_identity.current.account_id }
        ArnLike      = { "aws:SourceArn" = "arn:aws:bedrock-agentcore:${local.region}:${data.aws_caller_identity.current.account_id}:*" }
      }
    }]
  })
}

resource "aws_iam_role_policy" "fireantslab_runtime" {
  name = "execution"
  role = aws_iam_role.fireantslab_runtime.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken"]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["ecr:BatchGetImage", "ecr:GetDownloadUrlForLayer"]
        Resource = aws_ecr_repository.fireantslab_sandbox.arn
      },
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogStream", "logs:PutLogEvents", "logs:DescribeLogStreams"]
        Resource = "${aws_cloudwatch_log_group.fireantslab_runtime.arn}:*"
      },
      {
        Effect   = "Allow"
        Action   = ["bedrock:InvokeModel", "bedrock:InvokeModelWithResponseStream"]
        Resource = "*"
      },
    ]
  })
}

resource "aws_cloudwatch_log_group" "fireantslab_runtime" {
  name              = "/aws/bedrock-agentcore/${local.name_prefix}-fireantslab"
  retention_in_days = 30
}

# Two runtimes, not one. A scan is an unattended judgement whose result gates
# publication; a playground turn is someone poking at a skill. Sharing compute
# between them would let a playground session influence a verdict.
resource "aws_bedrockagentcore_agent_runtime" "fireantslab_scan" {
  agent_runtime_name = "fireants_scan"
  description        = "Detonation scans. Its output is evidence, never a verdict."
  role_arn           = aws_iam_role.fireantslab_runtime.arn

  agent_runtime_artifact {
    container_configuration {
      container_uri = "${aws_ecr_repository.fireantslab_sandbox.repository_url}:latest"
    }
  }

  # Egress is denied to the skill regardless; approved traffic leaves through
  # the gateway, never straight out of the sandbox.
  network_configuration {
    network_mode = "PUBLIC"
  }

  protocol_configuration {
    server_protocol = "HTTP"
  }

  environment_variables = {
    FIREANTS_ROLE     = "scan"
    FIREANTS_SITE_URL = "https://${local.fireantslab.domain}"
  }

  lifecycle {
    # CI publishes the image; Terraform must not roll it back on the next apply.
    ignore_changes = [agent_runtime_artifact]
  }
}

resource "aws_bedrockagentcore_agent_runtime" "fireantslab_playground" {
  agent_runtime_name = "fireants_playground"
  description        = "Interactive playground sessions over websockets."
  role_arn           = aws_iam_role.fireantslab_runtime.arn

  agent_runtime_artifact {
    container_configuration {
      container_uri = "${aws_ecr_repository.fireantslab_sandbox.repository_url}:latest"
    }
  }

  network_configuration {
    network_mode = "PUBLIC"
  }

  protocol_configuration {
    server_protocol = "HTTP"
  }

  # The admission grant is verified inside the runtime against stored session
  # state. A signed URL alone admits nobody.
  environment_variables = {
    FIREANTS_ROLE             = "playground"
    FIREANTS_SITE_URL         = "https://${local.fireantslab.domain}"
    FIREANTS_ADMISSION_SECRET = random_password.fireantslab_admission.result
  }

  lifecycle {
    ignore_changes = [agent_runtime_artifact]
  }
}

# ------------------------------------------------- Roles Vercel can assume ---

# Vercel deployments present an OIDC token, so no AWS key is ever stored there.
resource "aws_iam_openid_connect_provider" "vercel" {
  url             = local.fireantslab.vercel_oidc_issuer
  client_id_list  = ["https://vercel.com/${local.fireantslab.vercel_team}"]
  thumbprint_list = ["9e99a48a9960b14926bb7f3b02e22da2b0ab7280"]
}

locals {
  vercel_oidc_subject = "owner:${local.fireantslab.vercel_team}:project:fireantslab:environment:production"
}

# Presigning only. This role cannot start, stop or otherwise control a session,
# so a leaked presigned URL buys a connection and nothing more.
resource "aws_iam_role" "fireantslab_ws_signer" {
  name = "${local.name_prefix}-fireantslab-ws-signer"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = aws_iam_openid_connect_provider.vercel.arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${replace(local.fireantslab.vercel_oidc_issuer, "https://", "")}:sub" = local.vercel_oidc_subject
          "${replace(local.fireantslab.vercel_oidc_issuer, "https://", "")}:aud" = "https://vercel.com/${local.fireantslab.vercel_team}"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy" "fireantslab_ws_signer" {
  name = "presign-websocket"
  role = aws_iam_role.fireantslab_ws_signer.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = ["bedrock-agentcore:InvokeAgentRuntimeWithWebSocketStream"]
      Resource = [
        aws_bedrockagentcore_agent_runtime.fireantslab_playground.agent_runtime_arn,
        "${aws_bedrockagentcore_agent_runtime.fireantslab_playground.agent_runtime_arn}/*",
      ]
    }]
  })
}

# Stopping a session and dispatching a scan are deliberately somewhere else, so
# that the credential which signs browser URLs cannot cancel anyone's work.
resource "aws_iam_role" "fireantslab_control" {
  name = "${local.name_prefix}-fireantslab-control"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = aws_iam_openid_connect_provider.vercel.arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${replace(local.fireantslab.vercel_oidc_issuer, "https://", "")}:sub" = local.vercel_oidc_subject
          "${replace(local.fireantslab.vercel_oidc_issuer, "https://", "")}:aud" = "https://vercel.com/${local.fireantslab.vercel_team}"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy" "fireantslab_control" {
  name = "control"
  role = aws_iam_role.fireantslab_control.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "bedrock-agentcore:InvokeAgentRuntime",
          "bedrock-agentcore:StopRuntimeSession",
          "bedrock-agentcore:GetRuntimeSession",
        ]
        Resource = [
          aws_bedrockagentcore_agent_runtime.fireantslab_scan.agent_runtime_arn,
          "${aws_bedrockagentcore_agent_runtime.fireantslab_scan.agent_runtime_arn}/*",
          aws_bedrockagentcore_agent_runtime.fireantslab_playground.agent_runtime_arn,
          "${aws_bedrockagentcore_agent_runtime.fireantslab_playground.agent_runtime_arn}/*",
        ]
      },
    ]
  })
}

# ------------------------------------------------------------------ Vercel ---

resource "vercel_project" "fireantslab" {
  name      = "fireantslab"
  framework = "nextjs"

  git_repository = {
    type = "github"
    repo = local.fireantslab.github_repo
    # The deploy workflow pushes; a merge does not ship by itself.
    production_branch = "main"
  }

  # Lets the app exchange a deployment token for the AWS roles above, so no
  # AWS key is ever stored in Vercel.
  oidc_token_config = {
    issuer_mode = "team"
  }

  resource_config = {
    # Same region as Supabase and AgentCore: a request that crosses regions
    # pays for it on every database round trip.
    function_default_regions = ["bom1"]
    # An SSE relay spends its life waiting on a sandbox rather than on CPU.
    fluid = true
  }
}

resource "vercel_project_domain" "fireantslab" {
  project_id = vercel_project.fireantslab.id
  domain     = local.fireantslab.domain
}

resource "vercel_project_domain" "fireantslab_mcp" {
  project_id = vercel_project.fireantslab.id
  domain     = "mcp.${local.fireantslab.domain}"
}

locals {
  # The secret key and database URL are not here: they are set in the Vercel
  # dashboard so they never enter Terraform state, which the developer group
  # cannot read but which is still one more copy than necessary.
  fireantslab_env = {
    SITE_URL                 = "https://${local.fireantslab.domain}"
    NEXT_PUBLIC_SUPABASE_URL = "https://${supabase_project.fireantslab.id}.supabase.co"
    SUPABASE_URL             = "https://${supabase_project.fireantslab.id}.supabase.co"
    SUPABASE_STORAGE_BUCKET  = "skill-archives"
    BLOB_DRIVER              = "supabase"
    # The request server executes nothing and reports the capability as absent.
    SANDBOX_DRIVER                   = "none"
    AWS_REGION                       = local.region
    AGENTCORE_RUNTIME_ARN            = aws_bedrockagentcore_agent_runtime.fireantslab_playground.agent_runtime_arn
    AGENTCORE_CONNECT_WINDOW_SECONDS = tostring(local.fireantslab.connect_window_seconds)
    AWS_WS_SIGNER_ROLE_ARN           = aws_iam_role.fireantslab_ws_signer.arn
    AWS_CONTROL_ROLE_ARN             = aws_iam_role.fireantslab_control.arn
  }
}

resource "vercel_project_environment_variable" "fireantslab" {
  for_each = local.fireantslab_env

  project_id = vercel_project.fireantslab.id
  key        = each.key
  value      = each.value
  target     = ["production"]
}

resource "vercel_project_environment_variable" "fireantslab_admission" {
  project_id = vercel_project.fireantslab.id
  key        = "AGENTCORE_ADMISSION_SECRET"
  value      = random_password.fireantslab_admission.result
  target     = ["production"]
  sensitive  = true
}

# ------------------------------------------------------------- Cloudflare ---

data "cloudflare_zone" "fireantslab" {
  filter = {
    name = local.fireantslab.domain
  }
}

# Proxied would put Cloudflare in front of Vercel's own edge for no gain, and
# the websocket goes straight to AWS regardless.
resource "cloudflare_dns_record" "fireantslab_apex" {
  zone_id = data.cloudflare_zone.fireantslab.zone_id
  name    = local.fireantslab.domain
  type    = "A"
  content = "76.76.21.21"
  ttl     = 3600
  proxied = false
}

resource "cloudflare_dns_record" "fireantslab_www" {
  zone_id = data.cloudflare_zone.fireantslab.zone_id
  name    = "www"
  type    = "CNAME"
  content = "cname.vercel-dns.com"
  ttl     = 3600
  proxied = false
}

resource "cloudflare_dns_record" "fireantslab_mcp" {
  zone_id = data.cloudflare_zone.fireantslab.zone_id
  name    = "mcp"
  type    = "CNAME"
  content = "cname.vercel-dns.com"
  ttl     = 3600
  proxied = false
}
