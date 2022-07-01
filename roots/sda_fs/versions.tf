terraform {
  required_version = ">= 1.0.0"

  required_providers {
    aws = {
      version = ">= 3.61.0"
    }

    helm = {
      version = ">= 2.5.0"
    }

    kubernetes = {
      version = ">= 2.5.0"
    }
    sops = {
      source = "carlpett/sops"
      version = "0.7.1"
    }
  }
}
