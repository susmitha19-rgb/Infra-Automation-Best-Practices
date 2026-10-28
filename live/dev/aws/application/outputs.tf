output "bucket_arn" {
  description = "ARN of the deployed S3 bucket."
  value       = module.s3_bucket.arn
}

output "bucket_name" {
  description = "Name of the deployed S3 bucket."
  value       = module.s3_bucket.name
}
