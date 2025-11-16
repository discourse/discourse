output "bucket_id" {
  description = "S3 bucket ID"
  value       = aws_s3_bucket.uploads.id
}

output "bucket_name" {
  description = "S3 bucket name"
  value       = aws_s3_bucket.uploads.bucket
}

output "bucket_arn" {
  description = "S3 bucket ARN"
  value       = aws_s3_bucket.uploads.arn
}

output "bucket_domain_name" {
  description = "S3 bucket domain name"
  value       = aws_s3_bucket.uploads.bucket_domain_name
}

output "bucket_regional_domain_name" {
  description = "S3 bucket regional domain name"
  value       = aws_s3_bucket.uploads.bucket_regional_domain_name
}
