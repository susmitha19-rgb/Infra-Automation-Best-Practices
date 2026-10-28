output "instance_id" {
  description = "EC2 instance ID."
  value       = module.instance.id
}

output "private_ip" {
  description = "Private IP address of the EC2 instance."
  value       = module.instance.private_ip
}
