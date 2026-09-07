variable "name" {
  type = string
}

variable "repository" {
  description = "owner/repo"
  type        = string
}

variable "oidc_provider_arn" {
  type = string
}

variable "policy_json" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
