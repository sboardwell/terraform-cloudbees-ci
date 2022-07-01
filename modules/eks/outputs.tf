output "kubeconfig_filename" {
  value = local.kubeconfig_file
}

output "cluster_name" {
  value = module.eks.cluster_id
}

output "cluster_endpoint" {
  value = local.cluster_endpoint
}

output "cluster_ca_certificate" {
  value = local.cluster_ca_certificate
}

output "cluster_auth_token" {
  value = local.cluster_auth_token
}

output "domain_name" {
  value = local.domain_name
}
