output "vpc_id" {
  description = "The ID of the VPC"
  value       = aws_vpc.main.id
}

output "subnet_id" {
  description = "The ID of the Subnet"
  value       = aws_subnet.public_subnet.id
}

output "security_group_id" {
  description = "The ID of the Security Group"
  value       = aws_security_group.sg.id
}

