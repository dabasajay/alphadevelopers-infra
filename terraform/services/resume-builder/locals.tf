locals {
  app        = "resume-builder"
  name       = "${var.name_prefix}-${local.app}"
  tags       = { App = local.app }
  ssm_prefix = "/${var.name_prefix}/${local.app}"

  # Only used on create. CI owns the image afterwards and the Lambda module
  # ignores later image_uri changes.
  image_tag = "bootstrap"

  # Same origin as the SPA, so the samesite=lax session cookie is sent on
  # fetch. A separate API domain would silently drop it.
  api_base_url = "https://${var.config.domain}/api"
}
