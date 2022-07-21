locals {
  ingress_annotations = lookup({
    alb = {
      "alb.ingress.kubernetes.io/scheme"      = "internet-facing"
      "alb.ingress.kubernetes.io/tags"        = join(",", [for k, v in var.tags : "${k}=${v}"])
      "alb.ingress.kubernetes.io/target-type" = "ip"
    },
  }, var.ingress_class, {})
}

################################################################################
# CloudBees CD/RO
################################################################################

locals {
  install_cdro    = alltrue([var.install_cdro, local.mysql_endpoint != "", var.cd_admin_password != "", var.cd_host_name != "", var.rwx_storage_class != ""])
  cd_license_data = fileexists(local.cd_license_file) ? file(local.cd_license_file) : ""
  cd_license_file = "${abspath(path.root)}/${var.cd_license_file}"
  mysql_endpoint  = local.install_mysql ? concat(module.mysql.*.dns_name, [""])[0] : var.database_endpoint
}

module "cloudbees_cd" {
  count  = local.install_cdro ? 1 : 0
  source = "../cloudbees-cd"

  admin_password      = var.cd_admin_password
  chart_version       = var.cd_chart_version
  cjoc_url            = "http://${coalesce(module.cloudbees_ci.*.cjoc_url)}"
  database_endpoint   = local.mysql_endpoint
  database_name       = var.database_name
  database_password   = var.database_password
  database_user       = var.database_user
  host_name           = var.cd_host_name
  ingress_annotations = local.ingress_annotations
  ingress_class       = var.ingress_class
  license_data        = local.cd_license_data
  namespace           = var.cd_namespace
  platform            = var.platform
  rwx_storage_class   = var.rwx_storage_class
}


################################################################################
# CloudBees CI
################################################################################

locals {
  mc_bundle_dir  = "${abspath(path.root)}/${var.mc_bundle_dir}"
  mc_bundles = [ for file in fileset(local.mc_bundle_dir, "**/bundle.yaml") : basename(dirname("${file}")) ]
  mc_bundle_data = {
    for mc_single_bundle in local.mc_bundles : mc_single_bundle => {
      for mc_bundle_file in fileset("${local.mc_bundle_dir}/${mc_single_bundle}", "*.{yml,yaml}") : mc_bundle_file => file("${local.mc_bundle_dir}/${mc_single_bundle}/${mc_bundle_file}")
    }
  }
  install_ci  = alltrue([var.install_ci, var.ci_host_name != ""])
  bundle_data = { for file in fileset(local.bundle_dir, "*.{yml,yaml}") : file => file("${local.bundle_dir}/${file}") }
  bundle_dir  = "${abspath(path.root)}/${var.bundle_dir}"
  groovy_data = { for file in fileset(local.groovy_dir, "*.groovy") : file => file("${local.groovy_dir}/${file}") }
  groovy_dir  = "${abspath(path.root)}/${var.groovy_dir}"
  secret_data = fileexists(var.secrets_file) ? merge(yamldecode(file(var.secrets_file)), var.additional_secret_data) : merge(var.additional_secret_data)

  prometheus_relabelings = lookup({
    eks = [{
      action       = "replace"
      replacement  = "/$${1}/prometheus/"
      sourceLabels = ["__meta_kubernetes_endpoints_name"]
      targetLabel  = "__metrics_path__"
    }]
  }, var.platform, [])
}

module "cloudbees_ci" {
  count  = local.install_ci ? 1 : 0
  source = "../cloudbees-ci"

  agent_image                = var.agent_image
  bundle_data                = local.bundle_data
  mc_bundle_data             = local.mc_bundle_data
  bundle_configmap_name      = var.oc_configmap_name
  chart_version              = var.ci_chart_version
  cjoc_image                 = var.oc_image
  cjoc_enabled               = var.oc_enabled
  controller_image           = var.controller_image
  cpu_request                = 2
  create_servicemonitors     = var.create_servicemonitors
  extra_groovy_configuration = local.groovy_data
  host_name                  = var.ci_host_name
  ingress_annotations        = local.ingress_annotations
  ingress_class              = var.ingress_class
  manage_namespace           = var.manage_ci_namespace
  memory_request             = 4
  namespace                  = var.ci_namespace
  platform                   = var.platform
  prometheus_relabelings     = local.prometheus_relabelings
  secret_data                = local.secret_data
  casc_secrets_mc_data       = local.secret_data
  storage_class              = var.storage_class
}


################################################################################
# MySQL (for CD/RO)
################################################################################

locals {
  install_mysql = alltrue([var.install_mysql, var.database_password != "", var.mysql_root_password != ""])
}

module "mysql" {
  count  = local.install_mysql ? 1 : 0
  source = "../mysql"

  database_name = var.database_name
  password      = var.database_password
  root_password = var.mysql_root_password
  user_name     = var.database_user
}


################################################################################
# Post-provisioning commands
################################################################################

resource "null_resource" "update_kubeconfig" {
  count =  alltrue([var.update_kubeconfig, var.kubeconfig_file != ""]) ? 1 : 0

  provisioner "local-exec" {
    command = "kubectl config set-context --current --namespace=${var.ci_namespace}"
    environment = {
      KUBECONFIG = var.kubeconfig_file
    }
  }
}