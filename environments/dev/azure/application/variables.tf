variable "state_resource_group_name" {
  description = "Resource group containing the Azure remote state storage account."
  type        = string
}

variable "state_storage_account_name" {
  description = "Azure remote state storage account."
  type        = string
}

variable "state_container_name" {
  description = "Private blob container holding Terraform state."
  type        = string
}

variable "storage_account_name" {
  description = "Globally unique storage account name."
  type        = string
}

variable "storage_replication_type" {
  description = "Storage redundancy option."
  type        = string
  default     = "LRS"
}

variable "tags" {
  description = "Tags applied to resources."
  type        = map(string)
  default     = {}
}
