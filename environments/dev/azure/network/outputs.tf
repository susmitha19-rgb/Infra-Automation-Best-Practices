output "resource_group_name" {
  description = "Resource group name for dependent layers."
  value       = module.resource_group.name
}

output "location" {
  description = "Azure region for dependent layers."
  value       = module.resource_group.location
}

output "virtual_network_id" {
  description = "Virtual network resource ID."
  value       = module.virtual_network.id
}

output "subnet_id" {
  description = "Workload subnet resource ID."
  value       = module.virtual_network.subnet_id
}
