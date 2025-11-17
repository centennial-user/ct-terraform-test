output "environment" {
  value = terraform.workspace
}

output "instance_id" {
  description = "The ID of the EC2 instance"
  value       = aws_instance.backup_ec2.id
}

output "instance_status" {
  description = "The instance status (check for 'running')"
  value       = aws_instance.backup_ec2.instance_state
}

output "ssm_connection_command" {
  description = "Command to connect to the instance using SSM Session Manager"
  value       = "aws ssm start-session --target ${aws_instance.backup_ec2.id} --region us-east-1"
}

output "ssm_session_policy_arn" {
  description = "ARN of the helper IAM policy that grants StartSession permissions (attach to your IAM user/role)"
  value       = aws_iam_policy.ssm_session_start_policy.arn
}

output "ec2_ip" {
  description = "Public IP (for instances with public access)"
  value       = aws_instance.backup_ec2.public_ip
}

output "vpc_id" {
  description = "The VPC ID where the instance is running"
  value       = local.selected_vpc_id
}

output "subnet_id" {
  description = "The subnet ID where the instance is running"
  value       = local.selected_subnet_id
}

output "s3_bucket" {
  description = "The S3 bucket for backups"
  value       = aws_s3_bucket.backup_bucket.bucket
}
