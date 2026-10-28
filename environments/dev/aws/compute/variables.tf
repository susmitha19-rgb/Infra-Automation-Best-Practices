variable "region" {
  description = "AWS region for this environment."
  type        = string
}

variable "state_bucket" {
  description = "S3 bucket containing the Terraform state files."
  type        = string
}

variable "state_region" {
  description = "AWS region containing the Terraform state bucket."
  type        = string
}

variable "instance_name" {
  description = "EC2 instance name tag."
  type        = string
}

variable "ami_id" {
  description = "AMI ID available in the selected region."
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type."
  type        = string
  default     = "t3.micro"
}

variable "tags" {
  description = "Tags applied to resources."
  type        = map(string)
  default     = {}
}
