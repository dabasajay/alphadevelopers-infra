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

  # Neither the image nor the environment is owned here. CI publishes what the
  # tag points at, and the runtime's own configuration — its model key above all
  # — is set on the console, so an apply must not roll either back.
  lifecycle {
    ignore_changes = [agent_runtime_artifact, environment_variables]
  }
}
