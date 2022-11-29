output "eks1_kubeconfig" {
  value = module.eks1.kubeconfig_filename
}

output "eks1_kubeconfig_command" {
  value = "export KUBECONFIG=${module.eks1.kubeconfig_filename}"
}

output "eks1_cluster_name" {
  value = module.eks1.cluster_name
}

output "eks1_cluster_endpoint" {
  value = module.eks1.cluster_endpoint
}

output "sda1_outputs" {
  value = module.sda1
}
