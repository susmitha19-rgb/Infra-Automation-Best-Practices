data "terraform_remote_state" "network" {
  backend = "azurerm"

  config = {
    resource_group_name  = var.state_resource_group_name
    storage_account_name = var.state_storage_account_name
    container_name       = var.state_container_name
    key                  = "azure/dev/network.tfstate"
    use_azuread_auth     = true
    use_cli              = true
  }
}

module "virtual_machine" {
  source = "git::https://dev.azure.com/REPLACE_ORG/REPLACE_PROJECT/_git/REPLACE_REPO//modules/compute/azure/linux-virtual-machine?ref=terraform-compute-azure-linux-virtual-machine-v1.0.0"

  name                 = var.virtual_machine_name
  size                 = var.virtual_machine_size
  resource_group_name  = data.terraform_remote_state.network.outputs.resource_group_name
  location             = data.terraform_remote_state.network.outputs.location
  subnet_id            = data.terraform_remote_state.network.outputs.subnet_id
  admin_username       = var.admin_username
  admin_ssh_public_key = var.admin_ssh_public_key
  tags                 = var.tags
}
