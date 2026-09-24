output "playground_ecr_repository_url" {
  description = "Where the playground's deploy workflow pushes its image."
  value       = module.playground_image.repository_url
}

output "skill_scanner_ecr_repository_url" {
  description = "Where the skill scanner's deploy workflow pushes its image."
  value       = module.skill_scanner_image.repository_url
}

output "playground_runtime_arn" {
  value = module.playground_runtime.arn
}

output "scan_runtime_arn" {
  value = module.scan_runtime.arn
}

# One role for the frontend: presigning and control alike. Two would have
# trusted the same principal, so the split was a claim rather than a boundary.
output "frontend_role_arn" {
  value = module.frontend.arn
}

output "deploy_role_arn" {
  description = "Assumed by the runtime deploy workflows to publish images and roll runtimes."
  value       = module.deploy_role.arn
}
