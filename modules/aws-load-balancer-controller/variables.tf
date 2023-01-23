variable "aws_account_id" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "chart_version" {
  default = "1.4.1"
}

variable "cluster_name" {
  type = string
}

variable "cluster_security_group_id" {
  type = string
}

variable "node_security_group_id" {
  type = string
}

variable "oidc_issuer" {
  type = string
}

variable "partition_dns" {
  default = "amazonaws.com"
  type    = string
}

variable "partition_id" {
  default = "aws"
  type    = string
}

variable "release_name" {
  default = "aws-load-balancer-controller"
}

variable "service_account_name" {
  default = "aws-load-balancer-controller"
}

variable "enable_ingress_rule" {
  default     = true
  type        = bool
  description = "This is no longer needed after terraform-aws-modules/terraform-aws-eks #2250"
}
