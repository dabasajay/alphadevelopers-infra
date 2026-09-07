data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Session Manager document for the read-only web console on the datastore host.
#
# portNumber is a literal, not a parameter. AWS's own
# AWS-StartPortForwardingSession takes it as a parameter, which would let anyone
# allowed to use that document forward to :22 or anything else bound on the
# host; the shared guardrails policy denies it for exactly that reason. Only
# localPortNumber is caller-supplied, and that is a port on their own machine.
resource "aws_ssm_document" "db_console" {
  name            = "${local.name}-db-console"
  document_type   = "Session"
  document_format = "JSON"
  tags            = local.tags

  content = jsonencode({
    schemaVersion = "1.0"
    description   = "Forward the ${local.app} read-only database console."
    sessionType   = "Port"
    parameters = {
      localPortNumber = {
        type           = "String"
        description    = "Port on your own machine to listen on."
        allowedPattern = "^[0-9]{1,5}$"
        # Client side only, so it is free to differ from the remote port. 8091
        # rather than 8081 because the app repo's docker-compose publishes local
        # pgweb on 8081, and mistaking production for local seed data is worth
        # designing out.
        default = "8091"
      }
    }
    properties = {
      type            = "LocalPortForwarding"
      portNumber      = tostring(var.console_port)
      localPortNumber = "{{ localPortNumber }}"
    }
  })
}
