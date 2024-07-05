# Docs: https://doc.traefik.io/traefik/routing/providers/kubernetes-ingress/
# Also: https://doc.traefik.io/traefik/getting-started/quick-start-with-kubernetes/

locals {
  match_labels = {
    "app.kubernetes.io/name"       = "traefik"
    "app.kubernetes.io/managed-by" = "terraform"
    "app.kubernetes.io/component"  = "ingress"
  }
}

resource "kubernetes_service_account" "traefik" {
  metadata {
    name      = "traefik"
    namespace = var.namespace
  }
}

resource "kubernetes_cluster_role" "traefik-rbac" {
  metadata {
    name = "traefik"
  }

  rule {
    api_groups = ["extensions", "networking.k8s.io"]
    resources  = ["ingressclasses", "ingresses"]
    verbs      = ["get", "list", "watch"]
  }
  rule {
    api_groups = ["extensions", "networking.k8s.io"]
    resources  = ["ingresses/status"]
    verbs      = ["update"]
  }

  rule {
    api_groups = [""]
    resources  = ["services", "endpoints"]
    verbs      = ["get", "list", "watch"]
  }

  # For some reason, it also needs to be allowed to watch secrets.
  # Apparently because TlS certs are also stored in secrets (which we don't use).
  rule {
    api_groups = [""]
    resources  = ["secrets"]
    verbs      = ["list", "watch"]
  }
}

resource "kubernetes_cluster_role_binding" "traefik-rbac" {
  metadata {
    name = "traefik"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.traefik-rbac.metadata.0.name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.traefik.metadata.0.name
    namespace = var.namespace
  }
}

resource "kubernetes_deployment" "traefik" {
  metadata {
    name      = "traefik"
    namespace = var.namespace
  }

  spec {
    replicas = 1
    strategy {
      # Can't do rolling updates because we're binding to port 80 on the node, which
      # can't be done twice.
      type = "Recreate"
    }

    selector {
      match_labels = local.match_labels
    }

    template {
      metadata {
        labels = local.match_labels
      }

      spec {
        service_account_name = kubernetes_service_account.traefik.metadata.0.name

        container {
          name  = "traefik"
          image = "traefik:v3.0"
          args = [
            "--providers.kubernetesingress=true",
            "--entrypoints.web.address=:8000/tcp",
            "--entrypoints.traefik.address=:9000/tcp",
            "--api.insecure=true", # enables api/dashboard on "traefik" entrypoint
            "--ping=true"          # enables /ping on "traefik" entrypoint
          ]

          port {
            container_port = 9000
            protocol       = "TCP"
            name           = "traefik"
          }

          port {
            container_port = 8000
            protocol       = "TCP"
            name           = "web"
            # Expose this on the host directly.
            # This is the simple workaround for not having "LoadBalancer" type Service support
            # on bare metal (easily)
            host_port = 80
          }

          liveness_probe {
            http_get {
              path   = "/ping"
              port   = "traefik"
              scheme = "HTTP"
            }
          }

          readiness_probe {
            http_get {
              path   = "/ping"
              port   = "traefik"
              scheme = "HTTP"
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_ingress_class" "traefik" {
  metadata {
    name = "traefik"
    annotations = {
      "ingressclass.kubernetes.io/is-default-class" = "true"
    }
  }

  spec {
    controller = "traefik.io/ingress-controller"
  }
}

# -------- DASHBOARD --------
# NOTE: Traefik will print an error "Skipping service: no endpoints" for this Service when it
# restarts. Reason: Traefik itself is the pod/endpoint backing the service. Since we use "Replace"
# startegy, there is no "Ready"-state Pod for the service yet when it restarts. This causes
# the log. The problem is resolved as soon as liveness/readiness probes for Traefik itself
# succeeed and it's added to the service.
resource "kubernetes_service" "traefik_dashboard" {
  metadata {
    name      = "traefik-dashboard"
    namespace = var.namespace
  }

  spec {
    selector = local.match_labels
    port {
      port = 9000
    }
  }
}

resource "kubernetes_ingress_v1" "traefik_dashboard" {
  metadata {
    name      = "traefik-dashboard"
    namespace = var.namespace
    annotations = {
      "gethomepage.dev/enabled"      = true
      "gethomepage.dev/name"         = "Traefik Dashboard"
      "gethomepage.dev/group"        = "Infra"
      "gethomepage.dev/pod-selector" = "app.kubernetes.io/name=traefik"
    }
  }

  spec {
    rule {
      host = "traefik.rpi"
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = kubernetes_service.traefik_dashboard.metadata.0.name
              port {
                number = 9000
              }
            }
          }
        }
      }
    }
  }
}
