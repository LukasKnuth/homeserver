locals {
  namespace = "apps"
}

resource "kubernetes_namespace" "apps" {
  metadata {
    name = local.namespace
  }
}


