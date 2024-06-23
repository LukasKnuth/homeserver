resource "kubernetes_namespace" "apps" {
  metadata {
    name = "apps"
  }
}

resource "kubernetes_deployment" "nginx" {
  metadata {
    name      = "nginx-test"
    namespace = kubernetes_namespace.apps.metadata.0.name
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "nginx"
      }
    }

    template {
      metadata {
        labels = {
          app = "nginx"
        }
      }

      spec {
        container {
          name  = "webserver"
          image = "nginx:latest"
        }
      }
    }
  }
}
