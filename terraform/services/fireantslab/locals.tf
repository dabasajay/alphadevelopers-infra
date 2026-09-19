locals {
  app  = "fireantslab"
  name = "${var.name_prefix}-${local.app}"
  tags = { App = local.app }
}
