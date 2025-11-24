# Use module outputs for provider config
data "aws_eks_cluster" "cluster" {
  name = module.eks.cluster_id
  depends_on = [module.eks]
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_id
  depends_on = [module.eks]
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.cluster.token
  # optional: load config_context or exec if using AWS CLI
}

provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.cluster.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.cluster.token
  }
}

resource "helm_release" "argocd" {
  name       = "idriss-argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = ">= 4.0.0" # pin to a chart-compatible version you want

  namespace  = "idriss-argocd"
  create_namespace = true

  values = [
    <<EOF
server:
  service:
    type: LoadBalancer
    # If you prefer an internal LB, configure annotations or type ClusterIP + Ingress.
configs:
  # Example: disable autoTLS or supply custom settings
EOF
  ]
}
