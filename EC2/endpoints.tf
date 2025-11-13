// VPC Endpoint for SSM
resource "aws_vpc_endpoint" "ssm_endpoint" {
  count               = var.enable_ssm_endpoints ? 1 : 0
  vpc_id              = aws_vpc.private_vpc.id
  service_name        = "com.amazonaws.${var.aws_region}.ssm"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.subnets[var.private_subnet_name].id]
  security_group_ids  = [aws_security_group.private_sg.id]
  private_dns_enabled = var.enable_ssm_private_dns
}

// VPC Endpoint for EC2 Messages
resource "aws_vpc_endpoint" "ec2messages_endpoint" {
  count               = var.enable_ssm_endpoints ? 1 : 0
  vpc_id              = aws_vpc.private_vpc.id
  service_name        = "com.amazonaws.${var.aws_region}.ec2messages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.subnets[var.private_subnet_name].id]
  security_group_ids  = [aws_security_group.private_sg.id]
  private_dns_enabled = var.enable_ssm_private_dns
}

// VPC Endpoint for SSM Messages
resource "aws_vpc_endpoint" "ssmmessages_endpoint" {
  count               = var.enable_ssm_endpoints ? 1 : 0
  vpc_id              = aws_vpc.private_vpc.id
  service_name        = "com.amazonaws.${var.aws_region}.ssmmessages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.subnets[var.private_subnet_name].id]
  security_group_ids  = [aws_security_group.private_sg.id]
  private_dns_enabled = var.enable_ssm_private_dns
}
