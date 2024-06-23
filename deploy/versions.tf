terraform {
  required_providers {
    kubernetes = {
      source = "hashicorp/kubernetes"
      version = "2.31.0"
    }
  }
}

provider "kubernetes" {
  # Using the KUBE_CONFIG_PATH env variable
  config_context = "admin@home_cgn"
}
