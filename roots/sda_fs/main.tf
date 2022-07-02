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

provider "kubernetes" {
  alias = "eks2"
  host = module.eks2.cluster_endpoint
  cluster_ca_certificate = module.eks2.cluster_ca_certificate
  exec {
    api_version = "client.authentication.k8s.io/v1alpha1"
    args        = ["eks", "get-token", "--cluster-name", module.eks2.cluster_name]
    command     = "aws"
  }
}

provider "helm" {
  alias = "eks2"
  kubernetes {
    host = module.eks2.cluster_endpoint
    cluster_ca_certificate = module.eks2.cluster_ca_certificate
    exec {
      api_version = "client.authentication.k8s.io/v1alpha1"
      args        = ["eks", "get-token", "--cluster-name", module.eks2.cluster_name]
      command     = "aws"
    }
  }
}

# the service accounts are only found after installation of sda
data "external" "sa1" {
  program = [
    "bash",
    "-c",
    "export KUBECONFIG=${module.eks1.kubeconfig_filename}; [ -n \"$(kubectl get sa -n ${var.ci_namespace} jenkins --ignore-not-found)\" ] && { RES=$(kubectl view-serviceaccount-kubeconfig jenkins -n ${var.ci_namespace} 2>&1) && jq -n --arg res \"$RES\" '{\"status\": \"success\", \"out\":$res}' || jq -n --arg res \"$RES\" '{\"status\": \"error\", \"out\":$res}';} || echo '{\"status\": \"not found\"}'"
  ]
}
data "external" "sa2" {
  program = [
    "bash",
    "-c",
    "export KUBECONFIG=${module.eks2.kubeconfig_filename}; [ -n \"$(kubectl get sa -n ${var.ci_namespace} jenkins --ignore-not-found)\" ] && { RES=$(kubectl view-serviceaccount-kubeconfig jenkins -n ${var.ci_namespace} 2>&1) && jq -n --arg res \"$RES\" '{\"status\": \"success\", \"out\":$res}' || jq -n --arg res \"$RES\" '{\"status\": \"error\", \"out\":$res}';} || echo '{\"status\": \"not found\"}'"
  ]
}

locals {
  ci_host_name1 = "ci.${module.eks1.domain_name}"
  ci_host_name2 = "ci.${module.eks2.domain_name}"
  // NOTE: the hard-coded url is needed due to https://github.com/jenkinsci/configuration-as-code-plugin/issues/2015
  additional_secret_data1 = alltrue([data.external.sa1.result.status == "success", data.external.sa2.result.status == "success"]) ? {
    "sa-jenkins-local-jenkins-url": "https://${local.ci_host_name1}/releases-r23322",
    "sa-jenkins-local.yaml": data.external.sa1.result.out,
    "sa-jenkins-local-namespace": var.ci_namespace,
    "sa-jenkins-remote-jenkins-url": "https://${local.ci_host_name2}/releases-r23322",
    "sa-jenkins-remote.yaml": data.external.sa2.result.out,
    "sa-jenkins-remote-namespace": var.ci_namespace
    } : {}
  // NOTE: the hard-coded url is needed due to https://github.com/jenkinsci/configuration-as-code-plugin/issues/2015
  additional_secret_data2 = alltrue([data.external.sa1.result.status == "success", data.external.sa2.result.status == "success"]) ? {
    "sa-jenkins-remote-jenkins-url": "https://${local.ci_host_name1}/releases-r23322",
    "sa-jenkins-remote.yaml": data.external.sa1.result.out,
    "sa-jenkins-remote-namespace": var.ci_namespace,
    "sa-jenkins-local-jenkins-url": "https://${local.ci_host_name2}/releases-r23322",
    "sa-jenkins-local.yaml": data.external.sa2.result.out,
    "sa-jenkins-local-namespace": var.ci_namespace
    } : {}
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

module "eks2" {
  source   = "../../modules/eks"

  providers = {
    kubernetes = kubernetes.eks2
    helm = helm.eks2
  }

  base_domain = var.base_domain
  sub_domain = "c2" # var.sub_domain
  cluster_name = "sbo-tf-ci-c2" # var.cluster_name
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
  oc_enabled = var.oc_enabled
  secrets_file = var.secrets_file
  storage_class = var.storage_class
  ci_namespace = var.ci_namespace
  tags = var.tags
}

module "sda2" {
  depends_on = [ module.eks2 ]
  source = "../../modules/sda"

  providers = {
    kubernetes = kubernetes.eks2
    helm = helm.eks2
  }

  additional_secret_data = local.additional_secret_data2
  ci_host_name = "ci.c2.sboardwell.core.pscbdemos.com"
  cluster_name = module.eks2.cluster_name
  ingress_class = "alb"
  install_ci = var.install_ci
  kubeconfig_file = module.eks2.kubeconfig_filename
  bundle_dir =  var.bundle_dir
  oc_enabled = var.oc_enabled
  secrets_file = var.secrets_file
  ci_namespace = var.ci_namespace
  storage_class = var.storage_class
  tags = var.tags
}
