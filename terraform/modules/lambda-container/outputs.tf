output "function_name" {
  value = aws_lambda_function.this.function_name
}

output "function_arn" {
  value = aws_lambda_function.this.arn
}

output "function_url_domain" {
  description = "Host only, for use as a CloudFront origin."
  value       = var.enable_function_url ? replace(replace(aws_lambda_function_url.this[0].function_url, "https://", ""), "/", "") : null
}
