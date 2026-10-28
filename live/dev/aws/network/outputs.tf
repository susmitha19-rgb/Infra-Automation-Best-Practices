output "vpc_id" {
  description = "VPC ID for dependent layers."
  value       = module.vpc.id
}

output "subnet_id" {
  description = "Private subnet ID for dependent layers."
  value       = module.vpc.subnet_id
}
