output "kubeconfig_filename" {
  value = local.kubeconfig_file
}

output "cluster_name" {
  value = module.eks.cluster_id
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "cluster_ca_certificate" {
  value = base64decode(module.eks.cluster_certificate_authority_data)
}

output "cluster_auth_token" {
  value = local.cluster_auth_token
}

output "domain_name" {
  value = local.domain_name
}
