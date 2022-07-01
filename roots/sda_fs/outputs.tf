output "eks1_cluster_name" {
  value = module.eks1.cluster_name
}

output "eks1_cluster_endpoint" {
  value = module.eks1.cluster_endpoint
}

output "eks2_cluster_name" {
  value = module.eks2.cluster_name
}

output "eks2_cluster_endpoint" {
  value = module.eks2.cluster_endpoint
}

output "sda1_outputs" {
  value = module.sda1
}

output "sda2_outputs" {
  value = module.sda2
}
