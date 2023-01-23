terraform {
  required_version = ">= 1.0.0"

  required_providers {
    aws = {
      version = ">= 4.47"
    }

    helm = {
      version = ">= 2.5.0"
    }

    kubernetes = {
      version = ">= 2.10.0"
    }

    sops = {
      source = "carlpett/sops"
      version = ">= 0.7.1"
    }
  }
}
