terraform {
  required_providers {
    aws = {
      version = ">= 3.61.0"
    }

    helm = {
      version = ">= 2.5.0"
    }

    kubernetes = {
      version = ">= 2.9.0"
    }
  }
}
