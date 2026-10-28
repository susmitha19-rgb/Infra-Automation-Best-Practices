variable "name" {
  description = "Name tag for the VPC."
  type        = string
}

variable "cidr_block" {
  description = "IPv4 CIDR block for the VPC."
  type        = string
}

variable "subnet_name" {
  description = "Name tag for the private subnet."
  type        = string
}

variable "subnet_cidr_block" {
  description = "IPv4 CIDR block for the private subnet."
  type        = string
}

variable "availability_zone" {
  description = "Availability zone for the private subnet."
  type        = string
}

variable "tags" {
  description = "Tags applied to AWS resources."
  type        = map(string)
  default     = {}
}
