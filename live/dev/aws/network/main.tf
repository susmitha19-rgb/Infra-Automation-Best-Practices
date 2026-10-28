module "vpc" {
  source = "git::https://dev.azure.com/REPLACE_ORG/REPLACE_PROJECT/_git/REPLACE_REPO//modules/network/aws/vpc?ref=terraform-network-aws-vpc-v1.0.0"

  name              = var.vpc_name
  cidr_block        = var.vpc_cidr
  subnet_name       = var.subnet_name
  subnet_cidr_block = var.subnet_cidr
  availability_zone = var.availability_zone
  tags              = var.tags
}
