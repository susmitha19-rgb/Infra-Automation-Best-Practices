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

module "storage_account" {
  source = "git::https://dev.azure.com/REPLACE_ORG/REPLACE_PROJECT/_git/REPLACE_REPO//modules/application/azure/storage-account?ref=terraform-application-azure-storage-account-v1.0.0"

  name                = var.storage_account_name
  resource_group_name = data.terraform_remote_state.network.outputs.resource_group_name
  location            = data.terraform_remote_state.network.outputs.location
  replication_type    = var.storage_replication_type
  tags                = var.tags
}
