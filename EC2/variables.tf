variable "aws_region" {
  type        = string
  description = "AWS region"
  default     = "us-east-1"
}
variable "aws_s3" {
  type        = string
  description = "S3 bucket for terraform state"
  default     = "centennial-tf-state"
}
variable "aws_dynamodb_table" {
  type        = string
  description = "DynamoDB table for terraform state locking"
  default     = "ct-tf-locks"
}

variable "name_prefix" {
  description = "Name prefix for resources"
  type        = string
  default     = "ct"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr must be a valid CIDR block"
  }
}

variable "subnets" {
  description = "List of subnet objects (type: list(object))"
  type = list(object({
    name         = string
    availability_zone = optional(string)
    cidr         = string
    map_public_ip_on_launch = optional(bool, false)
  }))
  default = [
    { name = "public-1", cidr = "10.0.0.0/24", map_public_ip_on_launch = true },
    { name = "private-1", cidr = "10.0.1.0/24" }
  ]
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "puppet_instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "key_name" {
  description = "SSH key name (if needed)"
  type        = string
  default     = ""
}

variable "common_tags" {
  description = "Common tags applied to resources"
  type        = map(string)
  default     = {
    Owner = "team"
    Env   = "dev"
  }
}

variable "create_nat" {
  description = "Create a NAT gateway in the public subnet"
  type        = bool
  default     = true
}

variable "enable_ssm_endpoints" {
  description = "Create SSM/SSMMessages/EC2Messages endpoints"
  type        = bool
  default     = true
}

variable "enable_ssm_private_dns" {
  description = "Enable private DNS for SSM endpoints"
  type        = bool
  default     = false
}

variable "public_subnet_name" {
  description = "Key name of the public subnet in the subnets list"
  type        = string
  default     = "public-1"
}

variable "private_subnet_name" {
  description = "Key name of the private subnet in the subnets list"
  type        = string
  default     = "private-1"
}

variable "allowed_cidrs" {
  description = "List of CIDRs allowed into security group"
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "enable_puppet" {
   description = "Enable Puppet Master and Agent deployment"
   type        = bool
   default     = false
 }

 variable "puppet_agent_count" {  
   description = "Number of Puppet Agent instances to create"
   type        = number
   default     = 1
 }

 variable "puppet_domain" {
   description = "Domain name for Puppet Master and Agents"
   type        = string
   default     = "puppet.local"
 }