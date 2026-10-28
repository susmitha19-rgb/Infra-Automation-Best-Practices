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

variable "virtual_machine_name" {
  description = "Linux VM name."
  type        = string
}

variable "virtual_machine_size" {
  description = "Azure VM size."
  type        = string
  default     = "Standard_B2s"
}

variable "admin_username" {
  description = "Linux administrator username."
  type        = string
}

variable "admin_ssh_public_key" {
  description = "SSH public key for the VM administrator."
  type        = string
}

variable "tags" {
  description = "Tags applied to resources."
  type        = map(string)
  default     = {}
}
