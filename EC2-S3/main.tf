provider "aws" {
  region = "us-east-1"
}

# Use workspace name to build environment-specific resources
locals {
  env = terraform.workspace
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

resource "aws_iam_instance_profile" "profile" {
  name = "ec2_s3_profile_${local.env}"
  role = aws_iam_role.ec2_role.name
}

# ------------------------------------
# Security Group
# ------------------------------------
resource "aws_security_group" "ec2_sg" {
  name        = "ec2_sg_${local.env}"
  description = "Allow SSH"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

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
  key_name               = var.key_name
  iam_instance_profile   = aws_iam_instance_profile.profile.name
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]

  user_data = <<EOF
#!/bin/bash
yum update -y
yum install -y awscli

# Create test files
mkdir -p /opt/testfiles
echo "File1 created at $(date)" > /opt/testfiles/file1.txt
echo "File2 created at $(date)" > /opt/testfiles/file2.txt
echo "File3 created at $(date)" > /opt/testfiles/file3.txt

# Create backup script
cat << 'SCRIPT' > /usr/local/bin/s3_backup.sh
#!/bin/bash
aws s3 cp /opt/testfiles s3://idriss-backup-bucket-${local.env}/ --recursive
SCRIPT
chmod +x /usr/local/bin/s3_backup.sh

# Create cron job to run every 3 hours
echo "0 */3 * * * root /usr/local/bin/s3_backup.sh" >> /etc/crontab
EOF

  tags = {
    Name = "ec2-backup-${local.env}"
  }
}
