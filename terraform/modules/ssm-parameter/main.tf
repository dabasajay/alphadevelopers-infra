# Values are populated out of band by Ansible, so Terraform never holds the
# secret and it never lands in state. ignore_changes keeps that from drifting.
resource "aws_ssm_parameter" "this" {
  for_each = var.parameters

  name        = "${var.prefix}/${each.key}"
  description = each.value.description
  type        = each.value.secure ? "SecureString" : "String"
  value       = each.value.initial_value
  tier        = "Standard"
  tags        = var.tags

  lifecycle {
    ignore_changes = [value]
  }
}
