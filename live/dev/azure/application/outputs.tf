output "resource_group_name" {
  description = "Name of the deployed resource group."
  value       = data.terraform_remote_state.network.outputs.resource_group_name
}

output "storage_account_id" {
  description = "Resource ID of the deployed storage account."
  value       = module.storage_account.id
}

output "storage_account_name" {
  description = "Name of the deployed storage account."
  value       = module.storage_account.name
}
