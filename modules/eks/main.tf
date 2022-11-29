data "aws_caller_identity" "current" {}
data "aws_availability_zones" "available" {}

data "aws_eks_cluster_auth" "auth" {
  name = module.eks.cluster_id
}

data "aws_region" "current" {}

data "aws_route53_zone" "domain" {
  count = !local.create_zone ? 1 : 0
  name = local.domain_name
}

locals {
  availability_zones     = slice(data.aws_availability_zones.available.names, 0, var.zone_count)
  aws_account_id         = data.aws_caller_identity.current.account_id
  aws_region             = data.aws_region.current.name
  cluster_auth_token     = data.aws_eks_cluster_auth.auth.token
  cluster_name           = "${var.cluster_name}${local.workspace_suffix}"
  default_storage_class  = "gp2"
  ingress_class_name     = "alb"
  kubeconfig_file        = "${abspath(path.root)}/${var.kubeconfig_file}_${local.cluster_name}"
  this                   = toset(["this"])
  workspace_suffix       = terraform.workspace == "default" ? "" : "-${terraform.workspace}"

  vpc_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
  }

  alb_annotations = {
    "alb.ingress.kubernetes.io/actions.ssl-redirect" = "{\"Type\": \"redirect\", \"RedirectConfig\": { \"Protocol\": \"HTTPS\", \"Port\": \"443\", \"StatusCode\": \"HTTP_301\"}}"
    "alb.ingress.kubernetes.io/listen-ports"         = "[{\"HTTP\": 80}, {\"HTTPS\":443}]"
    "alb.ingress.kubernetes.io/scheme"               = "internet-facing"
    "alb.ingress.kubernetes.io/tags"                 = join(",", [for k, v in var.tags : "${k}=${v}"])
    "alb.ingress.kubernetes.io/target-type"          = "ip"
  }

  alb_redirect_path = {
    pathType = "ImplementationSpecific"
    backend = {
      service = {
        name = "ssl-redirect"
        port = {
          name = "use-annotation"
        }
      }
    }
  }
  create_zone = alltrue([var.base_domain != "", var.sub_domain != ""])
  domain_name = local.create_zone ? "${var.sub_domain}.${var.base_domain}" : "${var.domain_name}"
  domain_id = local.create_zone ? aws_route53_zone.sub_domain[0].id : data.aws_route53_zone.domain[0].id
}


################################################################################
# Amazon VPC
################################################################################

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "3.13.0"

  name                 = "${local.cluster_name}-vpc"
  cidr                 = var.cidr_block
  azs                  = local.availability_zones
  private_subnets      = [for i in range(0, var.zone_count) : cidrsubnet(var.cidr_block, 4, i)]
  public_subnets       = [for i in range(0, var.zone_count) : cidrsubnet(var.cidr_block, 4, var.zone_count +  i)]
  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true

  public_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                      = "1"
    "subnet-type"                                 = "public"
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"             = "1"
    "subnet-type"                                 = "private"
  }

  tags = local.vpc_tags
}

module "bastion" {
  for_each = var.bastion_enabled ? local.this : []
  source   = "../aws-bastion"

  key_name                 = var.key_name
  resource_prefix          = local.cluster_name
  source_security_group_id = module.eks.node_security_group_id
  ssh_cidr_blocks          = var.ssh_cidr_blocks
  subnet_id                = module.vpc.public_subnets.0
  vpc_id                   = module.vpc.vpc_id
}


################################################################################
# Amazon EKS cluster
################################################################################

module "iam" {
  source = "../eks-iam-roles"

  cluster_name = local.cluster_name
}

module "eks" {
  depends_on = [module.vpc]
  source  = "terraform-aws-modules/eks/aws"
  version = "18.17.0"

  cluster_name    = local.cluster_name
  cluster_version = var.kubernetes_version
  create_iam_role = false
  enable_irsa     = true
  iam_role_arn    = module.iam.cluster_role_arn
  subnet_ids      = module.vpc.private_subnets
  vpc_id          = module.vpc.vpc_id

  eks_managed_node_group_defaults = {
    min_size     = 1
    max_size     = 10
    desired_size = 1

    create_iam_role       = false
    create_security_group = false
    iam_role_arn          = module.iam.node_role_arn
    instance_types        = var.instance_types
    key_name              = var.key_name
    labels                = {}
    launch_template_tags  = var.tags
  }

  eks_managed_node_groups = { for index, zone in local.availability_zones :
    "${local.cluster_name}-${zone}" => {
      subnet_ids = [module.vpc.private_subnets[index]]
      capacity_type = "SPOT"
    }
  }

  node_security_group_additional_rules = {
    egress_self_all = {
      description = "Node to node all ports/protocols"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "egress"
      self        = true
    }

    ingress_self_all = {
      description = "Node to node all ports/protocols"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "ingress"
      self        = true
    }

    egress_ssh_all = {
      description = "Egress all ssh to internet for github"
      protocol    = "tcp"
      from_port   = 22
      to_port     = 22
      type        = "egress"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
    }
  }
}

################################################################################
# Hosted Zone
################################################################################

data "aws_route53_zone" "base_domain" {
  count = (local.create_zone) ? 1 : 0
  name         = var.base_domain
  private_zone = false
}

resource "aws_route53_zone" "sub_domain" {
  count = (local.create_zone) ? 1 : 0
  name = "${local.domain_name}"
  comment = "Managed by Terraform, Delegated Sub Zone for ${local.domain_name}"
  tags = var.tags
  force_destroy = true
}

resource "aws_route53_record" "aws_sub_zone_ns" {
  count = (local.create_zone) ? 1 : 0
  zone_id = "${data.aws_route53_zone.base_domain[0].zone_id}"
  name = "${local.domain_name}"
  type    = "NS"
  ttl     = "30"
  records = [
    for awsns in aws_route53_zone.sub_domain.0.name_servers:
    awsns
  ]
}

################################################################################
# Amazon Certificate Manager certificate(s)
################################################################################

module "acm_certificate" {
  depends_on = [aws_route53_record.aws_sub_zone_ns, data.aws_route53_zone.domain]
  for_each = var.create_acm_certificate ? local.this : []
  source   = "../acm-certificate"

  domain_name = local.domain_name
  subdomain   = "*"
}


################################################################################
# Kubernetes resources
################################################################################

module "aws_load_balancer_controller" {
  depends_on = [module.acm_certificate, module.eks]
  source     = "../aws-load-balancer-controller"

  aws_account_id            = local.aws_account_id
  aws_region                = local.aws_region
  cluster_name              = local.cluster_name
  cluster_security_group_id = module.eks.cluster_security_group_id
  node_security_group_id    = module.eks.node_security_group_id
  oidc_issuer               = trimprefix(module.eks.cluster_oidc_issuer_url, "https://")
}

module "cluster_autoscaler" {
  depends_on = [module.eks]
  source     = "../cluster-autoscaler-eks"

  aws_account_id     = local.aws_account_id
  aws_region         = local.aws_region
  cluster_name       = local.cluster_name
  kubernetes_version = var.kubernetes_version
  oidc_issuer        = trimprefix(module.eks.cluster_oidc_issuer_url, "https://")
  patch_version      = 2
}

module "ebs_driver" {
  depends_on = [module.eks]
  source     = "../aws-ebs-csi-driver"

  aws_account_id   = local.aws_account_id
  aws_region       = local.aws_region
  cluster_name     = local.cluster_name
  oidc_issuer      = trimprefix(module.eks.cluster_oidc_issuer_url, "https://")
  volume_tags      = var.tags
}

module "efs_driver" {
  depends_on = [module.eks]
  source     = "../aws-efs-csi-driver"

  aws_account_id         = local.aws_account_id
  aws_region             = local.aws_region
  cluster_name           = local.cluster_name
  node_security_group_id = module.eks.node_security_group_id
  oidc_issuer            = trimprefix(module.eks.cluster_oidc_issuer_url, "https://")
  private_subnet_ids     = module.vpc.private_subnets
  vpc_id                 = module.vpc.vpc_id
}

module "external_dns" {
  depends_on = [module.eks]
  source     = "../external-dns-eks"

  aws_account_id  = local.aws_account_id
  cluster_name    = local.cluster_name
  oidc_issuer     = trimprefix(module.eks.cluster_oidc_issuer_url, "https://")
  route53_zone_id = local.domain_id
}

module "kubernetes_dashboard" {
  depends_on = [module.aws_load_balancer_controller]
  for_each   = var.install_kubernetes_dashboard ? local.this : []
  source     = "../kubernetes-dashboard"

  host_name           = "${var.dashboard_subdomain}.${local.domain_name}"
  ingress_annotations = local.alb_annotations
  ingress_class_name  = local.ingress_class_name
}

module "prometheus" {
  depends_on = [module.aws_load_balancer_controller]
  for_each   = var.install_prometheus ? local.this : []
  source     = "../prometheus"

  host_name           = "${var.grafana_subdomain}.${local.domain_name}"
  ingress_annotations = local.alb_annotations
  ingress_class_name  = local.ingress_class_name
  ingress_extra_paths = [local.alb_redirect_path]
}


################################################################################
# Post-provisioning commands
################################################################################

resource "null_resource" "update_kubeconfig" {
  count = var.create_kubeconfig_file ? 1 : 0

  provisioner "local-exec" {
    command = "aws eks update-kubeconfig --name ${module.eks.cluster_id} --kubeconfig ${local.kubeconfig_file}"
  }
}

resource "null_resource" "update_default_storage_class" {
  depends_on = [module.ebs_driver, module.efs_driver]
  count = (var.create_kubeconfig_file && var.update_default_storage_class) ? 1 : 0

  provisioner "local-exec" {
    command = "kubectl annotate --overwrite storageclass ${local.default_storage_class} storageclass.kubernetes.io/is-default-class=false"
    environment = {
      KUBECONFIG = local.kubeconfig_file
    }
  }

  provisioner "local-exec" {
    command = "kubectl annotate --overwrite storageclass ${module.ebs_driver.storage_class_name} storageclass.kubernetes.io/is-default-class=true"
    environment = {
      KUBECONFIG = local.kubeconfig_file
    }
  }
}
