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
  }
}

provider "kubernetes" {
  # Using the KUBE_CONFIG_PATH env variable
  config_context = "admin@home_cgn"
}

provider "minio" {
  minio_server = "192.168.107.4:9000"
}
