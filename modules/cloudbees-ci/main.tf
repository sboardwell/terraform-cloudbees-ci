data "kubernetes_ingress" "cjoc" {
  depends_on = [helm_release.this]

  metadata {
    name      = "cjoc"
    namespace = var.namespace
  }
}

data "kubernetes_resource" "crd" {
  for_each   = var.create_servicemonitors ? local.this : []
  depends_on = [kubernetes_namespace.this]

  api_version = "apiextensions.k8s.io/v1"
  kind        = "CustomResourceDefinition"

  // noinspection HCLUnknownBlockType
  metadata {
    name = "servicemonitors.monitoring.coreos.com"
  }
}

locals {
  bundle_values = local.create_bundle ? yamlencode({
    OperationsCenter = {
      CasC = {
        Enabled = true
      }

      ConfigMapName = var.bundle_configmap_name
    }
  }) : ""

  create_bundle = length(var.bundle_data) != 0
  create_secret = length(var.secret_data) != 0
  create_casc_secrets_mc = length(var.casc_secrets_mc_data) != 0

  mc_bundle_data = var.mc_bundle_data
  create_mc_bundle = length(local.mc_bundle_data) != 0

  optional_values = {
    "OperationsCenter.Image.dockerImage" = var.cjoc_image
    "Master.Image.dockerImage"           = var.controller_image
    "Agents.Image.dockerImage"           = var.agent_image
    "Persistence.StorageClass"           = var.storage_class
  }

  secret_values = local.create_secret ? yamlencode({
    OperationsCenter = {
      ContainerEnv = [
        {
          name  = "SECRETS"
          value = var.secret_mount_path
        }
      ]

      ExtraVolumes = concat(
        [{
          name = var.secret_name
          secret = {
            defaultMode = 0400
            secretName  = var.secret_name
          }
        }],
        [
          for mc_bundle in keys(local.mc_bundle_data) : {
            name = "mc-casc-bundle-${lower(replace(mc_bundle,"/\\W|_|\\s/","-"))}"
            configMap = {
              name  = "mc-casc-bundle-${lower(replace(mc_bundle,"/\\W|_|\\s/","-"))}"
            }
          }
        ]
      )

      ExtraVolumeMounts = concat(
        [{
          name      = var.secret_name
          mountPath = var.secret_mount_path
        }],
        [
        for mc_bundle in keys(local.mc_bundle_data) : {
          name = "mc-casc-bundle-${lower(replace(mc_bundle,"/\\W|_|\\s/","-"))}"
          mountPath = "${var.mc_bundle_base_mount_path}/${mc_bundle}"
        }
        ]
      )
    }
  }) : ""

  service_monitors = {
    cjoc = {
      matchLabels = {
        "app.kubernetes.io/name" = "cloudbees-core"
      }
    },

    controllers = {
      matchExpressions = [{
        key      = "com.cloudbees.cje.type"
        operator = "Exists"
      }]
    }
  }

  this = toset(["this"])

  values = yamlencode({
    OperationsCenter = {
      Enabled = var.cjoc_enabled
      Platform = var.platform
      HostName = var.host_name
      Protocol = "https"

      Resources = {
        Limits = {
          Cpu    = var.cpu_request
          Memory = "${var.memory_request}G"
        }

        Requests = {
          Cpu    = var.cpu_request
          Memory = "${var.memory_request}G"
        }
      }

      Ingress = {
        Class       = var.ingress_class
        Annotations = var.ingress_annotations
      }

      JavaOpts = "-Xms${var.memory_request / 2}g -Xmx${var.memory_request / 2}g -Dcom.cloudbees.jenkins.cjp.installmanager.CJPPluginManager.enablePluginCatalogInOC=true -Dcom.cloudbees.masterprovisioning.kubernetes.KubernetesMasterProvisioning.deleteClaim=true"

      ExtraGroovyConfiguration = var.extra_groovy_configuration
    }

    HibernationEnabled = var.hibernation_enabled
  })
}

resource "kubernetes_namespace" "this" {
  for_each = var.manage_namespace ? local.this : []

  metadata {
    name = var.namespace
  }
}

resource "helm_release" "this" {
  depends_on = [kubernetes_namespace.this]

  chart      = "cloudbees-core"
  name       = "cloudbees-ci"
  namespace  = var.namespace
  repository = var.chart_repository
  values     = [local.values, local.secret_values, local.bundle_values]
  version    = var.chart_version

  # Dynamically set values if the associated vars are set
  dynamic "set" {
    for_each = {for k, v in local.optional_values: k => v if v != ""}
    content {
      name  = set.key
      value = set.value
    }
  }
}

resource "kubernetes_config_map" "casc_bundle" {
  for_each   = local.create_bundle ? local.this : []
  depends_on = [kubernetes_namespace.this]

  metadata {
    name      = var.bundle_configmap_name
    namespace = var.namespace
    annotations = {}
    labels = {}
  }

  data = var.bundle_data
}

resource "kubernetes_config_map" "mc_casc_bundles" {
  for_each   = local.create_mc_bundle ? local.mc_bundle_data : {}
  depends_on = [kubernetes_namespace.this]

  metadata {
    name      = "mc-casc-bundle-${lower(replace(each.key,"/\\W|_|\\s/","-"))}"
    namespace = var.namespace
    annotations = {}
    labels = {}
  }

  data = each.value
}

resource "kubernetes_secret" "secrets" {
  for_each   = local.create_secret ? local.this : []
  depends_on = [kubernetes_namespace.this]

  metadata {
    name      = var.secret_name
    namespace = var.namespace
    annotations = {}
    labels = {}
  }

  data = var.secret_data
}

resource "kubernetes_secret" "casc_secrets_mc" {
  for_each   = local.create_casc_secrets_mc ? local.this : []
  depends_on = [kubernetes_namespace.this]

  metadata {
    name      = var.casc_secrets_mc_name
    namespace = var.namespace
    annotations = {}
    labels = {}
  }

  data = var.casc_secrets_mc_data
}

resource "kubernetes_manifest" "service_monitor" {
  for_each   = { for k, v in local.service_monitors : k => v if var.create_servicemonitors }
  depends_on = [data.kubernetes_resource.crd]

  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "ServiceMonitor"
    metadata   = {
      labels    = { release = "prometheus" }
      name      = each.key
      namespace = var.namespace
    }

    spec = {
      endpoints = [{
        interval    = "30s"
        port        = "http"
        relabelings = var.prometheus_relabelings
      }]

      namespaceSelector = {
        matchNames = [var.namespace]
      }

      selector = each.value
    }
  }
}
