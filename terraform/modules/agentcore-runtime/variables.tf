variable "name" {
  description = "Letters, digits and underscores only; AgentCore rejects hyphens."
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9_]{0,47}$", var.name))
    error_message = "must start with a letter and use only letters, digits and underscores, up to 48 characters."
  }
}

variable "description" {
  type = string
}

variable "role_arn" {
  description = "What the container runs as. Code inside the microVM can read its credentials."
  type        = string
}

variable "container_uri" {
  type = string
}

variable "network_mode" {
  description = "PUBLIC still denies the workload egress; approved traffic leaves through the gateway."
  type        = string
  default     = "PUBLIC"
}

variable "server_protocol" {
  type    = string
  default = "HTTP"
}
