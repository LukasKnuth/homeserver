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

resource "kubernetes_service" "nginx" {
  metadata {
    name      = "nginx-test"
    namespace = kubernetes_namespace.apps.metadata.0.name
  }

  spec {
    selector = { app = "nginx" }

    type = "ClusterIP"

    port {
      port = 80
    }
  }
}

resource "kubernetes_ingress_v1" "nginx" {
  metadata {
    name      = "nginx-test"
    namespace = kubernetes_namespace.apps.metadata.0.name
  }

  spec {
    rule {
      host = "test.rpi"
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = kubernetes_service.nginx.metadata.0.name
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }
}
