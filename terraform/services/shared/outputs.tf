output "zone_ids" {
  value = { for k, v in data.aws_route53_zone.this : k => v.zone_id }
}

output "waf_web_acl_arn" {
  description = "Null when disabled. CloudFront treats a null web_acl_id as no association."
  value       = var.waf_enabled ? module.waf[0].arn : null
}

output "backup_bucket_name" {
  value = module.backup_bucket.id
}

output "backup_access_key_id" {
  value = aws_iam_access_key.backup.id
}

output "backup_secret_access_key" {
  value     = aws_iam_access_key.backup.secret
  sensitive = true
}

output "github_oidc_provider_arn" {
  value = aws_iam_openid_connect_provider.github.arn
}

output "alerts_topic_arn" {
  value = aws_sns_topic.alerts.arn
}

output "alerts_edge_topic_arn" {
  value = aws_sns_topic.alerts_edge.arn
}
