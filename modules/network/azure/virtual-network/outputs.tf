output "id" {
  description = "Virtual network resource ID."
  value       = azurerm_virtual_network.this.id
}

output "subnet_id" {
  description = "Workload subnet resource ID."
  value       = azurerm_subnet.this.id
}
