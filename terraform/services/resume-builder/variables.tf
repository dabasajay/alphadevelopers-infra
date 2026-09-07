variable "name_prefix" {
  type = string
}

variable "domain" {
  type = string
}

variable "github_repo" {
  type = string
}

variable "zone_id" {
  type = string
}

variable "oidc_provider_arn" {
  type = string
}

variable "waf_web_acl_arn" {
  type    = string
  default = null
}

variable "developer_group" {
  description = "Existing IAM group the debug policy attaches to. Null to skip."
  type        = string
  default     = null
}
