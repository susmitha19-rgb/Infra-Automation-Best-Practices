module "s3_bucket" {
  source = "git::https://dev.azure.com/REPLACE_ORG/REPLACE_PROJECT/_git/REPLACE_REPO//modules/application/aws/s3-bucket?ref=terraform-application-aws-s3-bucket-v1.0.0"

  name = var.bucket_name
  tags = var.tags
}
