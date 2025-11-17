provider "aws" {
  region = "us-east-1"
}

# Use workspace name to build environment-specific resources
locals {
  env = terraform.workspace
}

# Computed selection for VPC and Subnet (prefer explicit variables, then lookup, then fallback)
locals {
  selected_vpc_id = var.vpc_id != "" ? var.vpc_id : (
    length(data.aws_vpc.selected) > 0 ? data.aws_vpc.selected[0].id : (
      length(aws_vpc.fallback) > 0 ? aws_vpc.fallback[0].id : null
    )
  )

  selected_subnet_id = var.subnet_id != "" ? var.subnet_id : (
    length(aws_subnet.fallback) > 0 ? aws_subnet.fallback[0].id : null
  )
}

# Try to find existing VPC(s) by tag Name if `var.vpc_id` is not provided.
# Use `aws_vpcs` (plural) which returns an empty list instead of failing
# when no matches are found. We can then optionally create a fallback VPC
# if nothing is found and `var.create_vpc_if_missing` is true.
data "aws_vpcs" "by_name" {
  filter {
    name   = "tag:Name"
    values = ["MyVPC"]
  }
}

# Validate that the found VPC actually exists (data source may return stale IDs)
data "aws_vpc" "selected" {
  count = length(data.aws_vpcs.by_name.ids) > 0 ? 1 : 0
  id    = data.aws_vpcs.by_name.ids[0]
}

# Optional fallback VPC created when no VPC found and `create_vpc_if_missing` is true.
resource "aws_vpc" "fallback" {
  count             = (var.vpc_id == "" && length(data.aws_vpc.selected) == 0 && var.create_vpc_if_missing) ? 1 : 0
  cidr_block        = var.fallback_vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "MyVPC"
  }
}

# If we created a fallback VPC, create a subnet in it so instances can launch.
resource "aws_subnet" "fallback" {
  count      = length(aws_vpc.fallback)
  vpc_id     = aws_vpc.fallback[0].id
  cidr_block = var.fallback_subnet_cidr

  tags = {
    Name = "MySubnet"
  }
}

# Create Internet Gateway for fallback VPC (needed for SSM Agent to reach endpoints)
resource "aws_internet_gateway" "fallback" {
  count  = length(aws_vpc.fallback)
  vpc_id = aws_vpc.fallback[0].id

  tags = {
    Name = "fallback-igw"
  }
}

# Create route table for fallback VPC with route to IGW
resource "aws_route_table" "fallback" {
  count  = length(aws_vpc.fallback)
  vpc_id = aws_vpc.fallback[0].id

  route {
    cidr_block      = "0.0.0.0/0"
    gateway_id      = aws_internet_gateway.fallback[0].id
  }

  tags = {
    Name = "fallback-rt"
  }
}

# Associate route table with fallback subnet
resource "aws_route_table_association" "fallback" {
  count          = length(aws_vpc.fallback)
  subnet_id      = aws_subnet.fallback[0].id
  route_table_id = aws_route_table.fallback[0].id
}

# Create VPC Endpoints for SSM (alternative for private subnets without IGW)
resource "aws_vpc_endpoint" "ssm" {
  count             = length(aws_vpc.fallback)
  vpc_id            = aws_vpc.fallback[0].id
  service_name      = "com.amazonaws.${var.aws_region}.ssm"
  vpc_endpoint_type = "Interface"
  private_dns_enabled = true

  subnet_ids = [aws_subnet.fallback[0].id]

  security_group_ids = [aws_security_group.vpc_endpoint[0].id]

  tags = {
    Name = "ssm-endpoint"
  }
}

resource "aws_vpc_endpoint" "ssm_messages" {
  count             = length(aws_vpc.fallback)
  vpc_id            = aws_vpc.fallback[0].id
  service_name      = "com.amazonaws.${var.aws_region}.ssmmessages"
  vpc_endpoint_type = "Interface"
  private_dns_enabled = true

  subnet_ids = [aws_subnet.fallback[0].id]

  security_group_ids = [aws_security_group.vpc_endpoint[0].id]

  tags = {
    Name = "ssm-messages-endpoint"
  }
}

resource "aws_vpc_endpoint" "ec2_messages" {
  count             = length(aws_vpc.fallback)
  vpc_id            = aws_vpc.fallback[0].id
  service_name      = "com.amazonaws.${var.aws_region}.ec2messages"
  vpc_endpoint_type = "Interface"
  private_dns_enabled = true

  subnet_ids = [aws_subnet.fallback[0].id]

  security_group_ids = [aws_security_group.vpc_endpoint[0].id]

  tags = {
    Name = "ec2-messages-endpoint"
  }
}

# Security group for VPC endpoints (allow HTTPS from instances)
resource "aws_security_group" "vpc_endpoint" {
  count       = length(aws_vpc.fallback)
  name        = "vpc-endpoint-sg-${local.env}"
  description = "Allow HTTPS traffic to VPC endpoints"
  vpc_id      = aws_vpc.fallback[0].id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.fallback_vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "vpc-endpoint-sg"
  }
}

# ------------------------------------
# S3 bucket (unique per environment)
# ------------------------------------
resource "aws_s3_bucket" "backup_bucket" {
  bucket        = "idriss-backup-bucket-${local.env}"
  force_destroy = true
}

# ------------------------------------
# IAM Role for EC2 → S3
# ------------------------------------
resource "aws_iam_role" "ec2_role" {
  name = "ec2_s3_backup_role_${local.env}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Principal = { Service = "ec2.amazonaws.com" }
      Effect    = "Allow"
    }]
  })
}

resource "aws_iam_role_policy" "ec2_policy" {
  name = "ec2_s3_policy_${local.env}"
  role = aws_iam_role.ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:*"]
      Resource = "*"
    }]
  })
}

# Attach AWS managed policy for Systems Manager Session Manager access
resource "aws_iam_role_policy_attachment" "ssm_managed_instance_core" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Optional helper policy: create a reusable IAM policy that grants permission
# to start/describe/terminate SSM sessions. We don't attach it automatically
# (to avoid modifying user principals); instead we output the ARN so you can
# attach it to whichever IAM user/role needs Session Manager access.
resource "aws_iam_policy" "ssm_session_start_policy" {
  name        = "ssm-session-start-policy-${local.env}"
  description = "Allows starting and managing SSM Session Manager sessions (for console/CLI access)."

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:StartSession",
          "ssm:TerminateSession",
          "ssm:ResumeSession",
          "ssm:DescribeInstanceInformation",
          "ssm:DescribeSessions",
          "ssm:GetConnectionStatus",
          "ssm:DescribeInstanceProperties"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ssmmessages:CreateControlChannel",
          "ssmmessages:CreateDataChannel",
          "ssmmessages:OpenControlChannel",
          "ssmmessages:OpenDataChannel",
          "ssmmessages:SendMessage"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "profile" {
  name = "ec2_s3_profile_${local.env}"
  role = aws_iam_role.ec2_role.name
}

# ------------------------------------
# Security Group
# ------------------------------------
resource "aws_security_group" "ec2_sg" {
  name        = "ec2_sg_${local.env}"
  description = "Allow SSM Session Manager access (no SSH required)"
  # Determine VPC ID to use (prefer explicit variable). If no explicit
  # VPC ID and a VPC with tag `Name=MyVPC` exists use that, otherwise use
  # the fallback VPC created here (when enabled).
  vpc_id = local.selected_vpc_id

  # No ingress rules needed for SSM Session Manager (uses HTTPS outbound to AWS APIs)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ------------------------------------
# EC2 instance (with cron job)
# ------------------------------------
resource "aws_instance" "backup_ec2" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  # No key pair needed when using Systems Manager Session Manager
  iam_instance_profile   = aws_iam_instance_profile.profile.name
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  # Choose subnet: prefer explicit variable, otherwise use the fallback subnet
  # created when a fallback VPC is created. If neither exists, Terraform
  # will error at apply — pass `-var "subnet_id=..."` to resolve.
  subnet_id = local.selected_subnet_id

  user_data = <<EOF
#!/bin/bash
set -ex

echo "=== Starting EC2 User Data Script ===" >> /var/log/user-data.log
date >> /var/log/user-data.log

# Update system and ensure SSM Agent is running
echo "Updating yum packages..." >> /var/log/user-data.log
yum update -y >> /var/log/user-data.log 2>&1 || true

echo "Installing required packages..." >> /var/log/user-data.log
yum install -y awscli amazon-ssm-agent >> /var/log/user-data.log 2>&1 || true

# Ensure SSM Agent is enabled and running
echo "Starting SSM Agent..." >> /var/log/user-data.log
systemctl enable amazon-ssm-agent >> /var/log/user-data.log 2>&1
systemctl start amazon-ssm-agent >> /var/log/user-data.log 2>&1
systemctl status amazon-ssm-agent >> /var/log/user-data.log 2>&1

# Create test files
echo "Creating test files..." >> /var/log/user-data.log
mkdir -p /opt/testfiles || echo "Failed to create /opt/testfiles" >> /var/log/user-data.log
if [ -d /opt/testfiles ]; then
  echo "File1 created at $$(date)" > /opt/testfiles/file1.txt
  echo "File2 created at $$(date)" > /opt/testfiles/file2.txt
  echo "File3 created at $$(date)" > /opt/testfiles/file3.txt
  ls -la /opt/testfiles/ >> /var/log/user-data.log
  echo "Test files created successfully" >> /var/log/user-data.log
else
  echo "ERROR: /opt/testfiles directory does not exist" >> /var/log/user-data.log
fi

# Create backup script
echo "Creating backup script..." >> /var/log/user-data.log
mkdir -p /usr/local/bin
cat > /usr/local/bin/s3_backup.sh << 'SCRIPT'
#!/bin/bash
ENV="${local.env}"
aws s3 cp /opt/testfiles s3://idriss-backup-bucket-$$ENV/ --recursive
SCRIPT
chmod +x /usr/local/bin/s3_backup.sh
echo "Backup script created" >> /var/log/user-data.log

# Create cron job to run every 3 hours
echo "Setting up cron job..." >> /var/log/user-data.log
echo "0 */3 * * * root /usr/local/bin/s3_backup.sh" >> /etc/crontab
crontab -l >> /var/log/user-data.log 2>&1 || true
echo "Cron job configured" >> /var/log/user-data.log

echo "=== User Data Script Completed ===" >> /var/log/user-data.log
date >> /var/log/user-data.log
EOF

  tags = {
    Name = "ec2-backup-${local.env}"
  }
}
