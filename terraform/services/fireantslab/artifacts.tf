# Wraps each stored artifact's data key. The key never leaves KMS, so reading an
# artifact takes an authorized, logged call rather than a copy of the database.
#
# Destroying it makes every stored artifact unreadable, so Terraform refuses to.
resource "aws_kms_key" "artifacts" {
  description             = "Wraps FireAnts artifact data keys."
  enable_key_rotation     = true
  deletion_window_in_days = 30
  tags                    = local.tags

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_kms_alias" "artifacts" {
  name          = "alias/${local.name}-artifacts"
  target_key_id = aws_kms_key.artifacts.key_id
}
