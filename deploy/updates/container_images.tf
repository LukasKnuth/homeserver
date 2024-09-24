data "onepassword_item" "docker_hub" {
  vault = var.onepassword_vault_id
  uuid  = "5h6sphozmuti543vkjiih3xs6m"
}

resource "kubernetes_config_map_v1" "diun_config" {
  metadata {
    name      = "diun-config"
    namespace = var.namespace
  }

  data = {
    "diun.yaml" = yamlencode({
      watch = {
        # NOTE: we're explcitly NOT setting "schedule", because we want to run Diun
        # once _now_, scheduled through the Cron Job.
        schedule = null
        # TODO it has healthchecks integration here. Setup?
        runOnStartup : true
      }
      notif = {
        gotify = {
          endpoint = var.gotify_endpoint
          token    = var.gotify_application_token
          priority = 3
        }
      }
      regopts = [
        {
          name     = "docker.io"
          selector = "image"
          username = data.onepassword_item.docker_hub.username
          password = data.onepassword_item.docker_hub.password
        }
      ]
      providers = {
        kubernetes = {
          namespaces     = var.observe_namespaces
          watchByDefault = true
        }
      }
    })
  }
}

locals {
  descriptive_name = "diun-scan-container-updates"
  labels = {
    "app.kubernetes.io/name"       = "diun"
    "app.kubernetes.io/managed-by" = "terraform"
    "app.kubernetes.io/component"  = "monitoring"
  }
}

resource "kubernetes_service_account" "diun" {
  metadata {
    name      = local.descriptive_name
    namespace = var.namespace
  }
}

resource "kubernetes_cluster_role" "diun_rbac" {
  metadata {
    name = local.descriptive_name
  }

  rule {
    api_groups = [""]
    resources  = ["pods"]
    verbs      = ["get", "list"]
  }
}

resource "kubernetes_role_binding" "diun_rbac" {
  for_each = toset(var.observe_namespaces)

  metadata {
    name      = local.descriptive_name
    namespace = each.key
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.diun_rbac.metadata.0.name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.diun.metadata.0.name
    namespace = var.namespace
  }
}

resource "kubernetes_cron_job_v1" "diun" {
  metadata {
    name      = local.descriptive_name
    namespace = var.namespace
    labels    = local.labels
  }

  spec {
    schedule = var.cron_schedule

    job_template {
      metadata {
        labels = local.labels
      }

      spec {
        template {
          metadata {
            labels = local.labels
          }

          spec {
            service_account_name = kubernetes_service_account.diun.metadata.0.name

            volume {
              name = "config"
              config_map {
                name = kubernetes_config_map_v1.diun_config.metadata.0.name
              }
            }

            container {
              name  = "diun"
              image = "ghcr.io/crazy-max/diun:4.28.0"
              args  = ["serve"]

              volume_mount {
                name       = "config"
                mount_path = "/etc/diun/"
              }

              env {
                name  = "TZ"
                value = "Europe/Berlin"
              }
            }
          }
        }
      }
    }
  }
}
