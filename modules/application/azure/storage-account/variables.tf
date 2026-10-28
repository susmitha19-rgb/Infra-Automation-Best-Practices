variable "name" {
  description = "Globally unique Azure storage account name (3-24 lowercase letters and numbers)."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]{3,24}$", var.name))
    error_message = "The storage account name must contain 3-24 lowercase letters or numbers."
  }
}

variable "resource_group_name" {
  description = "Name of the resource group containing the storage account."
  type        = string
}

variable "location" {
  description = "Azure region for the storage account."
  type        = string
}

variable "replication_type" {
  description = "Storage redundancy option."
  type        = string
  default     = "LRS"

  validation {
    condition     = contains(["LRS", "ZRS", "GRS", "GZRS", "RAGRS", "RAGZRS"], var.replication_type)
    error_message = "Choose a supported Azure Storage replication type."
  }
}

variable "tags" {
  description = "Tags applied to the storage account."
  type        = map(string)
  default     = {}
}
