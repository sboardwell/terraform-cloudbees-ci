# Required variables
variable "cluster_name" {
  type = string
}

variable "domain_name" {
  type = string
  default = ""
}

variable "base_domain" {
  type = string
  default = ""
}

variable "sub_domain" {
  type = string
  default = ""
}

# Optional variables
variable "bastion_enabled" {
  default = false
  type    = bool
}

variable "cidr_block" {
  default = "10.0.0.0/16"
  type    = string

  validation {
    condition     = try(cidrhost(var.cidr_block, 0), null) != null
    error_message = "CIDR block was not in a valid CIDR format."
  }
}

variable "create_acm_certificate" {
  default = true
  type    = bool
}

variable "create_kubeconfig_file" {
  default = true
  type    = bool
}

variable "dashboard_subdomain" {
  default = "dashboard"
  type    = string
}

variable "grafana_subdomain" {
  default = "grafana"
  type    = string
}

variable "install_kubernetes_dashboard" {
  default = false
  type    = bool
}

variable "install_prometheus" {
  default = false
  type    = bool
}

variable "instance_types" {
  default = ["m5.xlarge", "m5a.xlarge", "m4.xlarge"]
  type    = set(string)
}

variable "key_name" {
  default = ""
  type    = string
}

variable "kubeconfig_file" {
  default = "eks_kubeconfig"
  type    = string
}

variable "kubernetes_version" {
  default = "1.21"
  type    = string

  validation {
    condition     = contains(["1.19", "1.20", "1.21"], var.kubernetes_version)
    error_message = "Provided Kubernetes version is not supported by EKS and/or CloudBees."
  }
}

variable "ssh_cidr_blocks" {
  default = ["0.0.0.0/32"]
  type    = list(string)

  validation {
    condition     = contains([for block in var.ssh_cidr_blocks : try(cidrhost(block, 0), "")], "") == false
    error_message = "List of SSH CIDR blocks contains an invalid CIDR block."
  }
}

variable "tags" {
  default = {}
  type    = map(string)
}

variable "update_default_storage_class" {
  default = true
  type    = string
}

variable "zone_count" {
  default = 3
  type    = number

  validation {
    condition     = var.zone_count > 0
    error_message = "Zone count must be non-zero and positive."
  }
}


# Required variables
variable "ingress_class" {
  type = string
}

variable "platform" {
  default = "eks"
  type = string

  validation {
    condition     = contains(["eks"], var.platform)
    error_message = "Not a tested/supported platform."
  }
}

# Common configuration
variable "update_kubeconfig" {
  default = true
  type    = bool
}

# Options for installing and configuring CloudBees CI
variable "install_ci" {
  default = false
  type    = bool
}

variable "agent_image" {
  default = ""
}

variable "create_servicemonitors" {
  default = false
  type    = bool
}

variable "mc_bundle_dir" {
  default = "cbci-casc-bundles"
  type    = string
}

variable "bundle_dir" {
  default = "oc-casc-bundle"
  type    = string
}

variable "ci_chart_repository" {
  default = "https://charts.cloudbees.com/public/cloudbees"
  type    = string
}

variable "ci_chart_version" {
  default = "3.43.1"
  type    = string
}

variable "ci_host_name" {
  default = ""
  type    = string
}

variable "ci_namespace" {
  default = "cloudbees-ci"
  type    = string
}

variable "controller_image" {
  default = ""
  type    = string
}

variable "groovy_dir" {
  default = "groovy-init"
  type    = string
}

variable "manage_ci_namespace" {
  default = true
  type    = bool
}

variable "oc_configmap_name" {
  default = "oc-casc-bundle"
  type    = string
}

variable "oc_image" {
  default = ""
  type    = string
}

variable "oc_enabled" {
  default = true
  type    = bool
}

variable "secrets_file" {
  default = "values/secrets.yaml"
  type    = string
}

variable "storage_class" {
  default = ""
  type    = string
}

# Options for installing and configuring CloudBees CD/RO
variable "install_cdro" {
  default = false
  type    = bool
}

variable "cd_admin_password" {
  default = ""
  type    = string
}

variable "cd_chart_version" {
  default = "2.13.2"
  type    = string
}

variable "cd_host_name" {
  default = ""
  type    = string
}

variable "cd_license_file" {
  default = "values/license.xml"
  type    = string
}

variable "cd_namespace" {
  default = "cloudbees-cd"
  type    = string
}

variable "database_endpoint" {
  default = ""
  type    = string
}

variable "database_name" {
  default = "flowdb"
  type    = string
}

variable "database_password" {
  default = ""
  type    = string
}

variable "database_user" {
  default = "flow"
  type    = string
}

variable "rwx_storage_class" {
  default = ""
  type    = string
}

# Options for installing and configuring a MySQL release
variable "install_mysql" {
  default = false
  type    = bool
}

variable "mysql_root_password" {
  default = ""
  type    = string
}
