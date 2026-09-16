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
    url = "https://${local.fireantslab.domain}"
    mcp = "https://mcp.${local.fireantslab.domain}/mcp"

    supabase_project_ref = supabase_project.fireantslab.id
    supabase_url         = "https://${supabase_project.fireantslab.id}.supabase.co"

    vercel_project_id = vercel_project.fireantslab.id

    sandbox_ecr_repository_url = aws_ecr_repository.fireantslab_sandbox.repository_url
    scan_runtime_arn           = aws_bedrockagentcore_agent_runtime.fireantslab_scan.agent_runtime_arn
    playground_runtime_arn     = aws_bedrockagentcore_agent_runtime.fireantslab_playground.agent_runtime_arn

    ws_signer_role_arn = aws_iam_role.fireantslab_ws_signer.arn
    control_role_arn   = aws_iam_role.fireantslab_control.arn
  }
}

# For the repository's deploy workflow secrets.
output "fireantslab_db_password" {
  value     = random_password.fireantslab_db.result
  sensitive = true
}
