variable "location" {
  description = "Azure region for this environment."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group name owned by the network layer."
  type        = string
}

variable "virtual_network_name" {
  description = "Virtual network name."
  type        = string
}

variable "address_space" {
  description = "Virtual network address spaces."
  type        = list(string)
}

variable "subnet_name" {
  description = "Workload subnet name."
  type        = string
}

variable "subnet_address_prefixes" {
  description = "Workload subnet address prefixes."
  type        = list(string)
}

variable "tags" {
  description = "Tags applied to resources."
  type        = map(string)
  default     = {}
}
