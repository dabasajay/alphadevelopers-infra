output "cloudfront_domain" {
  value = module.cdn.domain_name
}

output "distribution_id" {
  value = module.cdn.distribution_id
}

output "ecr_repository_url" {
  value = module.ecr.repository_url
}

output "api_function_name" {
  value = module.api.function_name
}

output "spa_bucket" {
  value = module.spa_bucket.id
}

output "pdf_bucket" {
  value = module.pdf_bucket.id
}

output "deploy_role_arn" {
  value = module.deploy_role.arn
}

output "db_console_document" {
  description = "aws ssm start-session --target <node> --document-name <this>"
  value       = aws_ssm_document.db_console.name
}
