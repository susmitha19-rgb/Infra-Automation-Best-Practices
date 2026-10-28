variable "name" {
  description = "Name of the virtual network."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group containing the virtual network."
  type        = string
}

variable "location" {
  description = "Azure region for the virtual network."
  type        = string
}

variable "address_space" {
  description = "IPv4 address spaces for the virtual network."
  type        = list(string)
}

variable "subnet_name" {
  description = "Name of the workload subnet."
  type        = string
}

variable "subnet_address_prefixes" {
  description = "IPv4 prefixes for the workload subnet."
  type        = list(string)
}

variable "tags" {
  description = "Tags applied to the virtual network."
  type        = map(string)
  default     = {}
}
