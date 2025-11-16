output "environment" {
  value = terraform.workspace
}

output "ec2_ip" {
  value = aws_instance.backup_ec2.public_ip
}

output "s3_bucket" {
  value = aws_s3_bucket.backup_bucket.bucket
}
