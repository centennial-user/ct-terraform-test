// IAM Role for EC2
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

// Attach Administrator policy
resource "aws_iam_role_policy_attachment" "ec2_admin_attach" {
  role       = aws_iam_role.ec2_admin_role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

// Attach SSM policy for Systems Manager access
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
