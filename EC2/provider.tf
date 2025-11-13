// Provider configuration
provider "aws" {
  region = var.aws_region
}

// Data sources
data "aws_availability_zones" "available" {}

data "aws_ssm_parameter" "latest_ami" {
  name = "/aws/service/ami-amazon-linux-latest/amzn2-ami-hvm-x86_64-gp2"
}
