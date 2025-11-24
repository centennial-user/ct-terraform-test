output "cluster_name" {
  value = module.eks.cluster_id
}

output "kubeconfig" {
  value = module.eks.kubeconfig
  sensitive = true
}

output "argocd_loadbalancer" {
  value = helm_release.argocd.status[0].load_balancer
  description = "Load balancer info for ArgoCD server (may need kubectl/console to retrieve external IP)."
  depends_on = [helm_release.argocd]
}

