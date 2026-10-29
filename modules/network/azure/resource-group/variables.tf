variable "name" {
  description = "Name of the resource group."
  type        = string
}

variable "location" {
  description = "Azure region for the resource group."
  type        = string
}

variable "tags" {
  description = "Tags applied to the resource group."
  type        = map(string)
  default     = {}

  validation {
    condition     = length(trimspace(lookup(var.tags, "environment", ""))) > 0 && lookup(var.tags, "managed_by", "") == "terraform"
    error_message = "Tags must include a non-empty environment and managed_by = terraform."
  }
}
