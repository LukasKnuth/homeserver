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
    api_groups = ["discovery.k8s.io"]
    resources  = ["endpointslices"]
    verbs      = ["list", "watch"]
  }

  rule {
    api_groups = [""]
    resources  = ["services", "nodes"]
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
        # Allow direct access to host network. This allows binding to IPv6 addresses
        # because the namespaced network for Pods is IPv4 only.
        host_network = true

        container {
          name  = "traefik"
          image = "traefik:v3.4.4"
          args = [
            "--providers.kubernetesingress=true",
            "--entrypoints.web.address=:80/tcp",
            "--entrypoints.traefik.address=127.0.0.1:9000/tcp",
            "--api.insecure=true", # enables api/dashboard on "traefik" entrypoint
            "--ping=true"          # enables /ping on "traefik" entrypoint
          ]

          port {
            # NOTE: Listens on loopback address and therefore isn't routed.
            # Use `just dashboard` port forward to local machine when needed.
            container_port = 9000
            protocol       = "TCP"
            name           = "traefik"
          }

          port {
            container_port = 80
            protocol       = "TCP"
            name           = "web"
            # Expose this on the host directly, in combination with `host_network = true`.
            # This is the simple workaround for not having "LoadBalancer" type Service support
            # on bare metal (easily)
            host_port = 80
          }

          # NOTE: We must specify `host = 127.0.0.1` here, because the `traefik` Endpoint above
          # is bound to the loopback interface explicitly. Since we using `host_network = true`,
          # the port would be publicly exposed, which we don't really want/need.
          liveness_probe {
            http_get {
              host   = "127.0.0.1"
              path   = "/ping"
              port   = "traefik"
              scheme = "HTTP"
            }
          }

          readiness_probe {
            http_get {
              host   = "127.0.0.1"
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

