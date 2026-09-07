locals {
  app  = "resume-builder"
  name = "${var.name_prefix}-${local.app}"
  tags = { App = local.app }
}
