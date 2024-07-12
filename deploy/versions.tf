terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.31.0"
    }

    minio = {
      source  = "aminueza/minio"
      version = "2.3.2"
    }

    gotify = {
      source  = "LukasKnuth/gotify"
      version = "0.2.1"
    }
  }
}

provider "kubernetes" {
  # Using the KUBE_CONFIG_PATH env variable
  config_context = "admin@home_cgn"
}

provider "minio" {
  # Entirely configured through ENV variables.
}

provider "gotify" {
  endpoint = "http://${var.cluster_static_ip}"
  # NOTE: Allows sending the API requests before DNS server was configured.
  host_header = "gotify.rpi"
  username    = "admin"
  password    = "admin"
}
