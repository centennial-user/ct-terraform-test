// Security Group for general EC2 instances
resource "aws_security_group" "private_sg" {
  name        = "${var.name_prefix}-sg"
  description = "Allow internal VPC traffic"
  vpc_id      = aws_vpc.private_vpc.id

  ingress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = var.allowed_cidrs
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.common_tags, { Name = "${var.name_prefix}-sg" })
}

// Security Group for Puppet (allows 8140 for puppet server)
resource "aws_security_group" "puppet_sg" {
  count       = var.enable_puppet ? 1 : 0
  name        = "${var.name_prefix}-puppet-sg"
  description = "Allow Puppet Master/Agent communication"
  vpc_id      = aws_vpc.private_vpc.id

  // Puppet Master listens on 8140
  ingress {
    protocol    = "tcp"
    from_port   = 8140
    to_port     = 8140
    cidr_blocks = var.allowed_cidrs
    description = "Puppet Master"
  }

  // SSH for testing
  ingress {
    protocol    = "tcp"
    from_port   = 22
    to_port     = 22
    cidr_blocks = var.allowed_cidrs
    description = "SSH"
  }

  // All outbound
  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.common_tags, { Name = "${var.name_prefix}-puppet-sg" })
}
