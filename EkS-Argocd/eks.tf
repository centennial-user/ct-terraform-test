module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = ">= 18.0.0" # choose a recent version

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version
  subnets         = data.aws_subnets.default.ids # or specify your subnets

  node_groups = {
    default = {
      desired_capacity = var.node_group_desired_capacity
      max_capacity     = var.node_group_desired_capacity + 1
      min_capacity     = 1

      instance_types = ["t3.medium"]
    }
  }

  # let the module create required IAM roles, security groups, etc.
  manage_aws_auth = true
}

# Example data source to use default VPC and subnets (replace with your networking)
data "aws_vpc" "default" {
  default = true
}
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}
