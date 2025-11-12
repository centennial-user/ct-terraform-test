# main.tf
/* provider "aws" {
  region = var.aws_region  # Change as needed
}

# VPC
resource "aws_vpc" "private_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = merge(var.common_tags, { Name = "${var.name_prefix}-vpc" })
}

# Public Subnet
resource "aws_subnet" "subnets" {
  for_each = { for s in var.subnets : s.name => s }

  vpc_id                  = aws_vpc.private_vpc.id
  cidr_block              = each.value.cidr
  availability_zone       = each.value.availability_zone != null ? each.value.availability_zone : data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = lookup(each.value, "map_public_ip_on_launch", false)

  tags = merge(var.common_tags, { Name = "${var.name_prefix}-${each.key}" })
}

# Private Subnet
resource "aws_subnet" "private_subnet" {
  vpc_id                  = aws_vpc.private_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = false
  availability_zone       = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "PrivateSubnet"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "public_igw" {
  vpc_id = aws_vpc.private_vpc.id

  tags = {
    Name = "PublicIGW"
  }
}

# NAT Gateway
resource "aws_eip" "nat_eip" {
  count = var.create_nat ? 1 : 0
  tags  = merge(var.common_tags, { Name = "${var.name_prefix}-nat-eip" })
}

resource "aws_nat_gateway" "private_nat" {
  count         = var.create_nat ? 1 : 0
  allocation_id = aws_eip.nat_eip[0].id
  subnet_id     = aws_subnet.subnets["public-1"].id
  tags = merge(var.common_tags, { Name = "${var.name_prefix}-nat" })
}

# Route Tables
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.private_vpc.id

  tags = {
    Name = "PublicRouteTable"
  }
}

resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.private_vpc.id

  tags = {
    Name = "PrivateRouteTable"
  }
}

# Routes
resource "aws_route" "public_route" {
  route_table_id         = aws_route_table.public_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.public_igw.id
}

*/

// Refactored main.tf to use variables, for_each and safer defaults
provider "aws" {
  region = var.aws_region
}

data "aws_availability_zones" "available" {}

// VPC
resource "aws_vpc" "private_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(var.common_tags, { Name = "${var.name_prefix}-vpc" })
}

// Subnets (created from a variable list)
resource "aws_subnet" "subnets" {
  for_each = { for s in var.subnets : s.name => s }

  vpc_id                  = aws_vpc.private_vpc.id
  cidr_block              = each.value.cidr
  availability_zone       = lookup(each.value, "availability_zone", data.aws_availability_zones.available.names[0])
  map_public_ip_on_launch = lookup(each.value, "map_public_ip_on_launch", false)

  tags = merge(var.common_tags, { Name = "${var.name_prefix}-${each.key}" })
}

// Internet Gateway
resource "aws_internet_gateway" "public_igw" {
  vpc_id = aws_vpc.private_vpc.id

  tags = merge(var.common_tags, { Name = "${var.name_prefix}-igw" })
}

// NAT Gateway (optional)
resource "aws_eip" "nat_eip" {
  count = var.create_nat ? 1 : 0
  tags  = merge(var.common_tags, { Name = "${var.name_prefix}-nat-eip" })
}

resource "aws_nat_gateway" "private_nat" {
  count         = var.create_nat ? 1 : 0
  allocation_id = aws_eip.nat_eip[0].id
  subnet_id     = aws_subnet.subnets[var.public_subnet_name].id

  tags = merge(var.common_tags, { Name = "${var.name_prefix}-nat" })
}

// Route Tables
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.private_vpc.id

  tags = merge(var.common_tags, { Name = "${var.name_prefix}-public-rt" })
}

resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.private_vpc.id

  tags = merge(var.common_tags, { Name = "${var.name_prefix}-private-rt" })
}

// Routes
resource "aws_route" "public_route" {
  route_table_id         = aws_route_table.public_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.public_igw.id
}

resource "aws_route" "private_route" {
  count                  = var.create_nat ? 1 : 0
  route_table_id         = aws_route_table.private_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.private_nat[0].id
}

// Subnet Associations
resource "aws_route_table_association" "public_subnet_association" {
  subnet_id      = aws_subnet.subnets[var.public_subnet_name].id
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_route_table_association" "private_subnet_association" {
  subnet_id      = aws_subnet.subnets[var.private_subnet_name].id
  route_table_id = aws_route_table.private_route_table.id
}

// Security Group
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

// IAM Role
resource "aws_iam_role" "ec2_admin_role" {
  name = "${var.name_prefix}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(var.common_tags, { Name = "${var.name_prefix}-ec2-role" })
}

resource "aws_iam_role_policy_attachment" "ec2_admin_attach" {
  role       = aws_iam_role.ec2_admin_role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

resource "aws_iam_role_policy_attachment" "ec2_ssm_attach" {
  role       = aws_iam_role.ec2_admin_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

// Instance Profile
resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "${var.name_prefix}-instance-profile"
  path = "/"
  role = aws_iam_role.ec2_admin_role.name
}

// VPC Endpoints for SSM (optional)
resource "aws_vpc_endpoint" "ssm_endpoint" {
  count               = var.enable_ssm_endpoints ? 1 : 0
  vpc_id              = aws_vpc.private_vpc.id
  service_name        = "com.amazonaws.${var.aws_region}.ssm"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.subnets[var.private_subnet_name].id]
  security_group_ids  = [aws_security_group.private_sg.id]
  private_dns_enabled = var.enable_ssm_private_dns
}

resource "aws_vpc_endpoint" "ec2messages_endpoint" {
  count               = var.enable_ssm_endpoints ? 1 : 0
  vpc_id              = aws_vpc.private_vpc.id
  service_name        = "com.amazonaws.${var.aws_region}.ec2messages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.subnets[var.private_subnet_name].id]
  security_group_ids  = [aws_security_group.private_sg.id]
  private_dns_enabled = var.enable_ssm_private_dns
}

resource "aws_vpc_endpoint" "ssmmessages_endpoint" {
  count               = var.enable_ssm_endpoints ? 1 : 0
  vpc_id              = aws_vpc.private_vpc.id
  service_name        = "com.amazonaws.${var.aws_region}.ssmmessages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.subnets[var.private_subnet_name].id]
  security_group_ids  = [aws_security_group.private_sg.id]
  private_dns_enabled = var.enable_ssm_private_dns
}


// EC2 Instance
resource "aws_instance" "private_ec2" {
  ami                    = data.aws_ssm_parameter.latest_ami.value
  instance_type          = var.instance_type
  key_name               = var.key_name != "" ? var.key_name : null
  subnet_id              = aws_subnet.subnets[var.private_subnet_name].id
  vpc_security_group_ids = [aws_security_group.private_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_instance_profile.name

  user_data = <<-EOF
    #!/bin/bash
    echo "Initializing EC2 with SSM Agent and Terraform" > /var/log/ssm-init.log
    yum update -y
    if ! systemctl status amazon-ssm-agent &>/dev/null; then
      yum install -y amazon-ssm-agent
      systemctl enable amazon-ssm-agent
      systemctl start amazon-ssm-agent
    fi
    yum install -y yum-utils unzip curl
    yum-config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo
    yum -y install terraform
    terraform -version >> /var/log/ssm-init.log
    echo "Setup complete at $(date)" >> /var/log/ssm-init.log
  EOF

  tags = merge(var.common_tags, { Name = "${var.name_prefix}-ec2" })
}

// Data sources
data "aws_ssm_parameter" "latest_ami" {
  name = "/aws/service/ami-amazon-linux-latest/amzn2-ami-hvm-x86_64-gp2"
}

// Outputs
output "vpc_id" {
  value = aws_vpc.private_vpc.id
}

output "private_subnet_id" {
  value = aws_subnet.subnets[var.private_subnet_name].id
}

output "public_subnet_id" {
  value = aws_subnet.subnets[var.public_subnet_name].id
}

output "security_group_id" {
  value = aws_security_group.private_sg.id
}

output "instance_profile" {
  value = aws_iam_instance_profile.ec2_instance_profile.name
}

output "role_name" {
  value = aws_iam_role.ec2_admin_role.name
}

output "ec2_instance_id" {
  value = aws_instance.private_ec2.id
}
