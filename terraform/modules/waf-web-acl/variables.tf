variable "name" {
  type = string
}

variable "rate_limit" {
  description = "Requests per 5 minutes per IP. WAF's floor is 100."
  type        = number
  default     = 2000
}

variable "enable_common_rules" {
  type    = bool
  default = false
}

variable "tags" {
  type    = map(string)
  default = {}
}
