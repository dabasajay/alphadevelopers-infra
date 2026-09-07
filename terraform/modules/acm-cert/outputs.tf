output "arn" {
  description = "From the validation resource, so consumers wait for the cert to be usable."
  value       = aws_acm_certificate_validation.this.certificate_arn
}
