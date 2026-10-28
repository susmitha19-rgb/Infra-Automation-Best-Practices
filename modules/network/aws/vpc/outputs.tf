output "id" {
  description = "VPC ID."
  value       = aws_vpc.this.id
}

output "subnet_id" {
  description = "Private subnet ID."
  value       = aws_subnet.this.id
}
