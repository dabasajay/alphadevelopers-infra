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
