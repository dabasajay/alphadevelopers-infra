variable "name" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "keep_last_images" {
  type    = number
  default = 5
}
