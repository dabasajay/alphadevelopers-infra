variable "prefix" {
  description = "Path prefix, e.g. /alphadevelopers/prod/resume-builder"
  type        = string
}

variable "parameters" {
  type = map(object({
    description   = string
    secure        = optional(bool, true)
    initial_value = optional(string, "placeholder-set-by-ansible")
  }))
}

variable "tags" {
  type    = map(string)
  default = {}
}
