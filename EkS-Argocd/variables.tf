variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "cluster_name" {
  type    = string
  default = "idriss-eks"
}

variable "cluster_version" {
  type    = string
  default = "1.27"
}

variable "node_group_desired_capacity" {
  type    = number
  default = 2
}

# (add other variables for node sizes, subnets, tags, etc.)
