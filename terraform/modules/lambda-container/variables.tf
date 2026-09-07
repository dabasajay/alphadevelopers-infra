variable "name" {
  type = string
}

variable "image_uri" {
  description = "Must already exist in ECR at create time. See README for the bootstrap push."
  type        = string
}

variable "image_command" {
  description = "Overrides the image CMD. Used to run a second handler from the same image."
  type        = list(string)
  default     = []
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

variable "environment" {
  description = "Seed values applied on create only. Later edits happen in the console; Terraform ignores the drift."
  type        = map(string)
  default     = {}
}

variable "policy_json" {
  type    = string
  default = null
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
