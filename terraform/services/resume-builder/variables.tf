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
