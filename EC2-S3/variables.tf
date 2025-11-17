variable "ami_id" {
  default = "ami-0c02fb55956c7d316"  # Amazon Linux 2
}

variable "instance_type" {
  default = "t2.micro"
}

variable "key_name" {
  description = "EC2 SSH key pair name"
  # Leave empty to launch instances without a key pair (no SSH access).
  # To use SSH, set this to an existing key pair name in your AWS account.
  default     = ""
}

variable "aws_region" {
  description = "AWS region where resources will be created"
  type        = string
  default     = "us-east-1"
}

variable "vpc_id" {
  description = "ID of the VPC to attach security group to. If empty, attempts to lookup a VPC tagged Name=MyVPC."
  type        = string
  default     = ""
}

variable "create_vpc_if_missing" {
  description = "If true and no matching VPC is found, create a VPC in this configuration." 
  type        = bool
  default     = true
}

variable "fallback_vpc_cidr" {
  description = "CIDR block to use when creating a fallback VPC (only used when create_vpc_if_missing=true)."
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_id" {
  description = "ID of an existing subnet to launch the instance into. If empty, a fallback subnet will be created when creating a fallback VPC."
  type        = string
  default     = ""
}

variable "fallback_subnet_cidr" {
  description = "CIDR block for the fallback subnet created when a fallback VPC is created."
  type        = string
  default     = "10.0.1.0/24"
}
