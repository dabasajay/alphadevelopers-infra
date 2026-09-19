variable "name_prefix" {
  type = string
}

variable "domain" {
  description = "Where the app is served. The runtimes are told, so they can name it back."
  type        = string
}

# The frontend is hosted outside this account and is not managed here. All this
# needs is enough to trust its OIDC tokens; where it runs is somebody else's
# concern until that moves into Terraform too.
variable "frontend_oidc_issuer" {
  type = string
}

variable "frontend_oidc_audience" {
  type = string
}

variable "frontend_oidc_subject" {
  description = "Narrows the trust to one project and environment, not the whole team."
  type        = string
}

variable "frontend_oidc_thumbprints" {
  type = list(string)
}
