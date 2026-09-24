# One Bedrock AgentCore runtime: a container that receives sessions.
#
# The image is deliberately not owned here. CI publishes what the tag points at
# once the runtime exists, and Terraform rolling it back on the next apply would
# undo a deploy nobody asked it to touch.
resource "aws_bedrockagentcore_agent_runtime" "this" {
  agent_runtime_name = var.name
  description        = var.description
  role_arn           = var.role_arn

  agent_runtime_artifact {
    container_configuration {
      container_uri = var.container_uri
    }
  }

  network_configuration {
    network_mode = var.network_mode
  }

  protocol_configuration {
    server_protocol = var.server_protocol
  }

  # A playground session is someone poking at a skill, not a long-lived service.
  # Idle reclaims the instance when the browser stops talking; max_lifetime caps
  # a session that never stops, because the conversation lives in that instance.
  lifecycle_configuration = [{
    idle_runtime_session_timeout = var.idle_session_timeout_seconds
    max_lifetime                 = var.max_lifetime_seconds
  }]

  # The environment is owned here, and empty: a runtime holds no configuration of
  # its own, so an apply clears anything set on it.
  lifecycle {
    ignore_changes = [agent_runtime_artifact]
  }
}
