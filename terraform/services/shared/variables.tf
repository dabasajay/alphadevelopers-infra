variable "name_prefix" {
  type = string
}

variable "zone_names" {
  type = list(string)
}

variable "backup_bucket_name" {
  type = string
}

variable "waf_enabled" {
  type    = bool
  default = false
}

variable "waf_rate_limit" {
  type    = number
  default = 2000
}

variable "waf_enable_common_rules" {
  type    = bool
  default = false
}

variable "alert_email" {
  description = "Subscribed to the alarm topic. Confirm the email AWS sends before alarms can notify."
  type        = string
}

variable "metrics_namespace" {
  description = "CloudWatch namespace the datastore host publishes into."
  type        = string
}

variable "datastore_host" {
  description = "Dimension value the host tags its metrics with."
  type        = string
}

variable "developer_group" {
  description = "Console-managed group. Terraform only attaches policies to it."
  type        = string
}

variable "region_locked_group" {
  description = "Console-managed group holding the region and destructive-action guardrail."
  type        = string
}

variable "state_bucket" {
  description = "Exempted from the destructive-action deny so the native state lock can be released."
  type        = string
}

variable "ssm_secret_prefix" {
  description = "Parameter Store prefix holding ansible's recovery secrets. Denied to developers."
  type        = string
}
