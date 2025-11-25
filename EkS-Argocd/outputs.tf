output "cluster_name" {
  value = aws_eks_cluster.main.name
}

output "kubeconfig" {
  description = "Kubeconfig YAML for connecting to the EKS cluster using aws eks get-token exec auth."
  value = yamlencode({
    apiVersion = "v1"
    kind       = "Config"
    clusters = [{
      name    = aws_eks_cluster.main.name
      cluster = {
        server                     = data.aws_eks_cluster.cluster.endpoint
        certificate-authority-data = data.aws_eks_cluster.cluster.certificate_authority[0].data
      }
    }]
    contexts = [{
      name    = aws_eks_cluster.main.name
      context = {
        cluster = aws_eks_cluster.main.name
        user    = aws_eks_cluster.main.name
      }
    }]
    "current-context" = aws_eks_cluster.main.name
    users = [{
      name = aws_eks_cluster.main.name
      user = {
        exec = {
          apiVersion = "client.authentication.k8s.io/v1beta1"
          command    = "aws"
          args       = [
            "eks",
            "get-token",
            "--region",
            var.aws_region,
            "--cluster-name",
            aws_eks_cluster.main.name
          ]
        }
      }
    }]
  })
  sensitive = true
}

output "argocd_loadbalancer" {
  description = "ArgoCD server LoadBalancer hostname or IP (may be null until provisioned)."
  value = try(
    coalesce(
      try(data.kubernetes_service.argocd_server.status[0].load_balancer[0].ingress[0].hostname, ""),
      try(data.kubernetes_service.argocd_server.status[0].load_balancer[0].ingress[0].ip, "")
    ),
    "LoadBalancer not yet provisioned"
  )
}

