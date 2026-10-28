output "id" {
  description = "Linux VM resource ID."
  value       = azurerm_linux_virtual_machine.this.id
}

output "private_ip_address" {
  description = "Private IP address of the VM's network interface."
  value       = azurerm_network_interface.this.private_ip_address
}
