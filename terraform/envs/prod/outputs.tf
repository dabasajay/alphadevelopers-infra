output "backup_bucket" {
  value = module.shared.backup_bucket_name
}

output "backup_iam_access_key_id" {
  description = "For pgBackRest on the VM. Put-only; cannot delete backups."
  value       = module.shared.backup_access_key_id
}

output "backup_iam_secret_access_key" {
  value     = module.shared.backup_secret_access_key
  sensitive = true
}

output "resume_builder" {
  value = {
    url                = "https://${local.resume_builder.domain}"
    cloudfront_domain  = module.resume_builder.cloudfront_domain
    distribution_id    = module.resume_builder.distribution_id
    ecr_repository_url = module.resume_builder.ecr_repository_url
    api_function_name  = module.resume_builder.api_function_name
    spa_bucket         = module.resume_builder.spa_bucket
    pdf_bucket         = module.resume_builder.pdf_bucket
    deploy_role_arn    = module.resume_builder.deploy_role_arn
  }
}

output "fireantslab" {
  value = {
    playground_ecr_repository_url    = module.fireantslab.playground_ecr_repository_url
    skill_scanner_ecr_repository_url = module.fireantslab.skill_scanner_ecr_repository_url
    scan_runtime_arn                 = module.fireantslab.scan_runtime_arn
    playground_runtime_arn           = module.fireantslab.playground_runtime_arn

    frontend_role_arn = module.fireantslab.frontend_role_arn
    deploy_role_arn   = module.fireantslab.deploy_role_arn
  }
}
