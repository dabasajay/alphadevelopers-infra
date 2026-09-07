variable "name_prefix" {
  type = string
}

variable "config" {
  type = object({
    domain               = string
    github_repo          = string
    redis_port           = number
    pg_database          = string
    pg_role              = string
    lambda_memory_mb     = optional(number, 1024)
    lambda_timeout       = optional(number, 30)
    lambda_reserved_conc = optional(number, 20)
    migrate_memory_mb    = optional(number, 512)
    migrate_timeout      = optional(number, 300)
    log_retention_days   = optional(number, 7)
    access_token_min     = optional(number, 30)
  })
}

variable "zone_id" {
  type = string
}

variable "waf_web_acl_arn" {
  type    = string
  default = null
}

variable "oidc_provider_arn" {
  type = string
}

variable "db_host" {
  type = string
}

variable "pgbouncer_port" {
  type = number
}
