# Use cluster outputs for provider config
data "aws_eks_cluster" "cluster" {
  name = aws_eks_cluster.main.name
}

data "aws_eks_cluster_auth" "cluster" {
  name = aws_eks_cluster.main.name
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

provider "helm" {
  kubernetes = {
    host                   = data.aws_eks_cluster.cluster.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.cluster.token
  }
}


resource "helm_release" "argocd" {
  name             = "idriss-argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = "7.3.0"
  namespace        = "idriss-argocd"
  create_namespace = true


  values = [
    <<EOF
server:
  service:
    type: LoadBalancer

configs:
  params:
    server.disable.auth: "false"
EOF
  ]

  depends_on = [aws_eks_node_group.main]
}

# Read the Argo CD server Service to expose its LoadBalancer address
data "kubernetes_service" "argocd_server" {
  metadata {
    name      = "argocd-server"
    namespace = "idriss-argocd"
  }

  depends_on = [helm_release.argocd]
}
