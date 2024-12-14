resource "kubernetes_config_map_v1" "dashboard_config" {
  metadata {
    name      = "dashboard-config"
    namespace = var.namespace
  }

  data = {
    "settings.yaml" = yamlencode({
      title = "Launchpad"
      theme = "light"
      color = "white"
      layout = [
        { Apps = { style = "row", columns = 3 } },
        { Monitoring = { columns = 1 } },
        { Infra = { columns = 1 } },
        { Work = { style = "row", columns = 3 } },
        { Tools = { style = "row", columns = 3 } },
        { Procrastinate = { style = "row", columns = 3 } },
      ]
      headerStyle = "boxed"
      language    = "en"
      target      = "_self"
      quicklaunch = {
        hideVisitURL = true
      }
      hideVersion = true
      hideErrors  = true
      statusStyle = "dot"
    })
    "bookmarks.yaml" = yamlencode(
      [for group, entries in var.bookmarks :
        { (group) = [for entry in entries :
          { (entry[0]) = [{ abbr = substr(join("", regexall("[A-Z0-9].*?", entry[0])), 0, 2), href = (entry[1]) }] }
        ] }
      ]
    )
    "services.yaml" = yamlencode([
      { Apps = [
        { JDownloader = {
          href = "https://my.jdownloader.org"
          ping = "192.168.107.4"
          widget = {
            type     = "jdownloader"
            client   = "JDownloader@root"
            username = data.onepassword_item.jdownloader.username
            password = data.onepassword_item.jdownloader.password
          }
        } }
      ] }
    ])
    "widgets.yaml" = yamlencode([
      {
        search = {
          provider = "custom"
          target   = "_self"
          # https://help.kagi.com/kagi/getting-started/setting-default.html#manual_configuration
          url                   = "https://kagi.com/search?q="
          suggestionUrl         = "https://kagi.com/api/autosuggest?q="
          showSearchSuggestions = true
        }
      },
    ])
    "kubernetes.yaml" = yamlencode({ mode = "cluster" })
    "custom.css"      = <<-EOT
    /* Disable clicking/hovering on search result box. This has no ID, but there is only one dialog element so far... */
    dialog {
      cursor: not-allowed;
    }
    dialog ul {
      pointer-events: none;
    }
    EOT
    # NOTE Even if we don't use them, we specify empty files here. This prevents
    # the Dashboard from trying to copy defaults to the readonly Filesystem
    "custom.js"   = ""
    "docker.yaml" = ""
  }
}

data "onepassword_item" "jdownloader" {
  vault = var.onepassword_vault_id
  uuid  = "4iovm26ps6faszs55bkllv6gsi"
}

locals {
  match_labels = {
    "app.kubernetes.io/name"       = "dashboard"
    "app.kubernetes.io/managed-by" = "terraform"
    "app.kubernetes.io/component"  = "app"
  }
}

resource "kubernetes_deployment" "dashboard" {
  metadata {
    name      = "dashboard"
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
        service_account_name = kubernetes_service_account.service_account.metadata.0.name

        volume {
          name = "config"
          config_map {
            name = kubernetes_config_map_v1.dashboard_config.metadata.0.name
          }
        }

        container {
          name  = "homepage"
          image = "ghcr.io/gethomepage/homepage:v0.9.13"

          env {
            name  = "LOG_TARGETS"
            value = "stdout"
          }

          volume_mount {
            name       = "config"
            mount_path = "/app/config"
          }

          port {
            container_port = 3000
            protocol       = "TCP"
            name           = "web"
          }

          liveness_probe {
            http_get {
              path   = "/api/healthcheck"
              port   = "web"
              scheme = "HTTP"
            }
          }

          readiness_probe {
            http_get {
              path   = "/api/healthcheck"
              port   = "web"
              scheme = "HTTP"
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "landing" {
  metadata {
    name      = "dashboard-landing"
    namespace = var.namespace
  }

  spec {
    selector = local.match_labels
    port {
      port = 3000
    }
  }
}

resource "kubernetes_ingress_v1" "landing" {
  metadata {
    name      = "dashboard-landing"
    namespace = var.namespace
  }

  spec {
    rule {
      host = "home.rpi"
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = kubernetes_service.landing.metadata.0.name
              port {
                number = 3000
              }
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_service_account" "service_account" {
  metadata {
    name      = "dashboard"
    namespace = var.namespace
  }
}

resource "kubernetes_cluster_role" "dashboard_rbac" {
  metadata {
    name = "dashboard"
  }

  rule {
    api_groups = [""]
    resources  = ["namespaces", "pods", "nodes"]
    verbs      = ["get", "list"]
  }
  rule {
    api_groups = ["extensions", "networking.k8s.io"]
    resources  = ["ingresses"]
    verbs      = ["get", "list"]
  }
  rule {
    api_groups = ["metrics.k8s.io"]
    resources  = ["nodes", "pods"]
    verbs      = ["get", "list"]
  }
  rule {
    api_groups = ["apiextensions.k8s.io"]
    resources  = ["customresourcedefinitions/status"]
    verbs      = ["get", "list"]
  }
}

resource "kubernetes_cluster_role_binding" "dashboard_rbac" {
  metadata {
    name = "dashboard"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.dashboard_rbac.metadata.0.name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.service_account.metadata.0.name
    namespace = var.apps_namespace
  }
}
