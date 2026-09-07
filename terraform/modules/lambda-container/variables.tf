variable "name" {
  type = string
}

variable "image_uri" {
  description = "Must already exist in ECR at create time. See README for the bootstrap push."
  type        = string
}

variable "memory_mb" {
  type    = number
  default = 1024
}

variable "timeout" {
  type    = number
  default = 30
}

variable "reserved_concurrency" {
  description = "Hard cap on concurrent executions. Bounds both the bill and the database connection count. -1 disables."
  type        = number
  default     = -1
}

variable "policy_json" {
  description = "Permissions beyond CloudWatch Logs. Required; a plan-time-unknown value cannot gate a count."
  type        = string
}

variable "log_retention_days" {
  type    = number
  default = 7
}

variable "enable_function_url" {
  type    = bool
  default = false
}

variable "tags" {
  type    = map(string)
  default = {}
}
