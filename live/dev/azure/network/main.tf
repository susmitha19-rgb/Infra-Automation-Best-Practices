module "resource_group" {
  source = "git::https://dev.azure.com/REPLACE_ORG/REPLACE_PROJECT/_git/REPLACE_REPO//modules/network/azure/resource-group?ref=terraform-network-azure-resource-group-v1.0.0"

  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

module "virtual_network" {
  source = "git::https://dev.azure.com/REPLACE_ORG/REPLACE_PROJECT/_git/REPLACE_REPO//modules/network/azure/virtual-network?ref=terraform-network-azure-virtual-network-v1.0.0"

  name                    = var.virtual_network_name
  resource_group_name     = module.resource_group.name
  location                = module.resource_group.location
  address_space           = var.address_space
  subnet_name             = var.subnet_name
  subnet_address_prefixes = var.subnet_address_prefixes
  tags                    = var.tags
}
