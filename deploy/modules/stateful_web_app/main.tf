locals {
  match_labels = {
    "app.kubernetes.io/name"       = var.name
    "app.kubernetes.io/managed-by" = "terraform"
  }
}

resource "kubernetes_deployment" "app" {
  metadata {
    name      = var.name
    namespace = var.namespace
  }

  spec {
    replicas = 1

    selector {
      match_labels = local.match_labels
    }

    template {
      metadata {
        labels = local.match_labels
      }

      spec {
        container {
          name  = var.name
          image = var.image

          dynamic "env" {
            for_each = var.env
            content {
              name  = each.key
              value = each.value
            }
          }

          port {
            container_port = var.expose_port
            protocol       = "TCP"
          }

          dynamic "liveness_probe" {
            for_each = var.liveness_get_path == null ? [] : [1]
            content {
              http_get {
                path   = var.liveness_get_path
                port   = var.expose_port
                scheme = "HTTP"
              }
            }
          }

          dynamic "readiness_probe" {
            for_each = var.readiness_get_path == null ? [] : [1]
            content {
              http_get {
                path   = var.readiness_get_path
                port   = var.expose_port
                scheme = "HTTP"
              }
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "web_service" {
  metadata {
    name      = var.name
    namespace = var.namespace
  }

  spec {
    selector = local.match_labels
    port {
      port = var.expose_port
    }
  }
}

resource "kubernetes_ingress_v1" "web_ingress" {
  metadata {
    name      = var.name
    namespace = var.namespace
  }

  spec {
    rule {
      host = var.fqdn
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = kubernetes_service.web_service.metadata.0.name
              port {
                number = kubernetes_service.web_service.spec.0.port.0.port
              }
            }
          }
        }
      }
    }
  }
}
