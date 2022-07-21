provider "aws" {
  default_tags {
    tags = var.tags
  }
}

provider "kubernetes" {
  alias = "eks1"
  host = module.eks1.cluster_endpoint
  cluster_ca_certificate = module.eks1.cluster_ca_certificate
  exec {
    api_version = "client.authentication.k8s.io/v1alpha1"
    args        = ["eks", "get-token", "--cluster-name", module.eks1.cluster_name]
    command     = "aws"
  }
}

provider "helm" {
  alias = "eks1"
  kubernetes {
    host = module.eks1.cluster_endpoint
    cluster_ca_certificate = module.eks1.cluster_ca_certificate
    exec {
      api_version = "client.authentication.k8s.io/v1alpha1"
      args        = ["eks", "get-token", "--cluster-name", module.eks1.cluster_name]
      command     = "aws"
    }
  }
}

locals {
  ci_host_name1 = "ci.${module.eks1.domain_name}"
  additional_secret_data1 = {}
}

module "eks1" {
  source   = "../../modules/eks"

  providers = {
    kubernetes = kubernetes.eks1
    helm = helm.eks1
  }

  base_domain = var.base_domain
  sub_domain = "c1" # var.sub_domain
  cluster_name = "sbo-tf-ci-c1" # var.cluster_name
  tags = var.tags
}

module "sda1" {
  depends_on = [ module.eks1 ]
  source = "../../modules/sda"

  providers = {
    kubernetes = kubernetes.eks1
    helm = helm.eks1
  }

  additional_secret_data = local.additional_secret_data1
  ci_host_name = local.ci_host_name1
  cluster_name = module.eks1.cluster_name
  ingress_class = "alb"
  install_ci = var.install_ci
  kubeconfig_file = module.eks1.kubeconfig_filename
  bundle_dir =  var.bundle_dir
  mc_bundle_dir =  var.mc_bundle_dir
  oc_enabled = var.oc_enabled
  secrets_file = var.secrets_file
  storage_class = var.storage_class
  ci_namespace = var.ci_namespace
  tags = var.tags
}
