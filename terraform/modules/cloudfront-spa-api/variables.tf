variable "name" {
  type = string
}

variable "aliases" {
  type = list(string)
}

variable "acm_certificate_arn" {
  type = string
}

variable "spa_bucket_id" {
  type = string
}

variable "spa_bucket_arn" {
  type = string
}

variable "spa_bucket_regional_domain_name" {
  type = string
}

variable "api_function_name" {
  type = string
}

variable "api_origin_domain" {
  description = "Lambda function URL host, no scheme or trailing slash."
  type        = string
}

variable "web_acl_arn" {
  type    = string
  default = null
}

variable "tags" {
  type    = map(string)
  default = {}
}
