resource "kubernetes_config_map_v1" "release_watcher_config" {
  metadata {
    name      = "release-watcher-config"
    namespace = var.namespace
  }

  data = {
    "release-watcher.yml" = yamlencode({

    })
  }
}

locals {
  labels = {
    "app.kubernetes.io/name"       = "release-watcher"
    "app.kubernetes.io/managed-by" = "terraform"
    "app.kubernetes.io/component"  = "monitoring"
  }
}

resource "kubernetes_cron_job_v1" "release_watcher" {
  metadata {
    name      = "release-watcher-scan-container-updates"
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
            volume {
              name = "config"
              config_map {
                name = kubernetes_config_map_v1.release_watcher_config.metadata.0.name
              }
            }

            container {
              name  = "release-watcher"
              image = ""
              args  = ["serve"]

              volume_mount {
                name       = "config"
                mount_path = "/etc/release-watcher/"
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
