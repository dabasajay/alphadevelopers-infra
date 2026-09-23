variable "name" {
  type = string
}

variable "subject_prefix" {
  # A repo with immutable subjects carries numeric ids, so this is not owner/repo.
  description = "The repository's sub_claim_prefix, from /actions/oidc/customization/sub."
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
