variable "region" {
  description = "AWS region for this environment."
  type        = string
}

variable "vpc_name" {
  description = "VPC name tag."
  type        = string
}

variable "vpc_cidr" {
  description = "IPv4 CIDR block for the VPC."
  type        = string
}

variable "subnet_name" {
  description = "Private subnet name tag."
  type        = string
}

variable "subnet_cidr" {
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
