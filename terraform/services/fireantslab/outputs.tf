output "ecr_repository_url" {
  description = "Where the deploy workflow pushes the playground image."
  value       = module.playground_image.repository_url
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
  description = "Assumed by the deploy workflow to publish the image and roll the runtimes."
  value       = module.deploy_role.arn
}
