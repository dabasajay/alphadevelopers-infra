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

variable "image_tag_mutability" {
  description = "IMMUTABLE pins a tag to one digest. A rolling tag needs MUTABLE."
  type        = string
}
