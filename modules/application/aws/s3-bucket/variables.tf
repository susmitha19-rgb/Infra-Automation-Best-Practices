variable "name" {
  description = "Globally unique S3 bucket name."
  type        = string

  validation {
    condition     = length(var.name) >= 3 && length(var.name) <= 63 && can(regex("^[a-z0-9][a-z0-9.-]*[a-z0-9]$", var.name))
    error_message = "The S3 bucket name must be 3-63 characters, use lowercase letters, numbers, dots, or hyphens, and start and end with a letter or number."
  }
}

variable "versioning_enabled" {
  description = "Whether object versioning is enabled."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags applied to the bucket."
  type        = map(string)
  default     = {}
}
