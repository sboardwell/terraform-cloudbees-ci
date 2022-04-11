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

variable "dns_suffix" {
  default = "amazonaws.com"
  type    = string
}

variable "ingress_class_name" {
  default = "alb"
  type    = string
}

variable "node_security_group_id" {
  type = string
}

variable "oidc_issuer" {
  type = string
}

variable "release_name" {
  default = "aws-load-balancer-controller"
}

variable "service_account_name" {
  default = "aws-load-balancer-controller"
}
