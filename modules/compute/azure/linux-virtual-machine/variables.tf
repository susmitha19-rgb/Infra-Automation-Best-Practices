variable "name" {
  description = "Name of the Linux virtual machine."
  type        = string
}

variable "size" {
  description = "Azure VM size."
  type        = string
  default     = "Standard_B2s"
}

variable "resource_group_name" {
  description = "Resource group containing the VM."
  type        = string
}

variable "location" {
  description = "Azure region for the VM."
  type        = string
}

variable "subnet_id" {
  description = "Subnet resource ID for the VM network interface."
  type        = string
}

variable "admin_username" {
  description = "Linux administrator username."
  type        = string
}

variable "admin_ssh_public_key" {
  description = "SSH public key installed on the VM. Never supply a private key."
  type        = string
}

variable "tags" {
  description = "Tags applied to Azure resources."
  type        = map(string)
  default     = {}
}
