data "terraform_remote_state" "network" {
  backend = "s3"

  config = {
    bucket = var.state_bucket
    key    = "aws/dev/network.tfstate"
    region = var.state_region
  }
}

module "instance" {
  source = "git::https://dev.azure.com/REPLACE_ORG/REPLACE_PROJECT/_git/REPLACE_REPO//modules/compute/aws/ec2-instance?ref=terraform-compute-aws-ec2-instance-v1.0.0"

  name          = var.instance_name
  ami_id        = var.ami_id
  instance_type = var.instance_type
  vpc_id        = data.terraform_remote_state.network.outputs.vpc_id
  subnet_id     = data.terraform_remote_state.network.outputs.subnet_id
  tags          = var.tags
}
