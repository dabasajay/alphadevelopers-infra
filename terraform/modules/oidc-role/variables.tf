variable "name" {
  type = string
}

variable "oidc_provider_arn" {
  type = string
}

variable "issuer_host" {
  description = "The issuer without its scheme. Claim conditions are keyed on it."
  type        = string
}

variable "claims" {
  description = "Claim name to required value, e.g. {sub = \"...\", aud = \"...\"}. Must not be empty."
  type        = map(string)
}

variable "policy_json" {
  type = string
}

variable "policy_name" {
  type    = string
  default = "inline"
}

variable "tags" {
  type    = map(string)
  default = {}
}
