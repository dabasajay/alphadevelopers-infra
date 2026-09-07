variable "name" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "versioning" {
  type    = bool
  default = false
}

variable "block_public_policy" {
  description = "Set false only when a bucket policy grants CloudFront OAC access."
  type        = bool
  default     = true
}

variable "object_lock_days" {
  description = "Zero disables Object Lock. Non-zero forces versioning on."
  type        = number
  default     = 0
}

variable "lifecycle_rules" {
  type = list(object({
    id                         = string
    prefix                     = optional(string, "")
    transitions                = optional(list(object({ days = number, storage_class = string })), [])
    expiration_days            = optional(number)
    noncurrent_expiration_days = optional(number)
  }))
  default = []
}
