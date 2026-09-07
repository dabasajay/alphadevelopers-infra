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

variable "alerts_topic_arn" {
  type = string
}

variable "alerts_edge_topic_arn" {
  description = "Must be a us-east-1 topic: CloudFront alarms live there."
  type        = string
}

variable "tfstate_bucket_arn" {
  description = "Denied to the developer group: state holds secrets in plaintext."
  type        = string
}

variable "datastore_instance_id" {
  description = "SSM managed node id of the datastore host, printed by the ansible ssm-agent role."
  type        = string
}

variable "console_port" {
  description = "Loopback port the read-only console is published on. Must match console_port in ansible group_vars."
  type        = number
}
