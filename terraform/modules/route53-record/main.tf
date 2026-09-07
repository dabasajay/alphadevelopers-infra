resource "aws_route53_record" "this" {
  for_each = toset(var.names)

  zone_id = var.zone_id
  name    = each.value
  type    = "A"

  alias {
    name = var.alias_target
    # Fixed global zone id for every CloudFront distribution.
    zone_id                = "Z2FDTNDATAQYW2"
    evaluate_target_health = false
  }
}
