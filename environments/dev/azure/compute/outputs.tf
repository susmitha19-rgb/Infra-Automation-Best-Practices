output "virtual_machine_id" {
  description = "Linux VM resource ID."
  value       = module.virtual_machine.id
}

output "private_ip_address" {
  description = "Private IP address of the VM."
  value       = module.virtual_machine.private_ip_address
}
