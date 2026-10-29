variable "name" {
  description = "Name tag for the EC2 instance."
  type        = string
}

variable "ami_id" {
  description = "Region-specific AMI ID for the instance."
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type."
  type        = string
  default     = "t3.micro"
}

variable "vpc_id" {
  description = "VPC ID for the instance security group."
  type        = string
}

variable "subnet_id" {
  description = "Private subnet ID for the instance."
  type        = string
}

variable "tags" {
  description = "Tags applied to AWS resources."
  type        = map(string)
  default     = {}

  validation {
    condition     = length(trimspace(lookup(var.tags, "environment", ""))) > 0 && lookup(var.tags, "managed_by", "") == "terraform"
    error_message = "Tags must include a non-empty environment and managed_by = terraform."
  }
}
