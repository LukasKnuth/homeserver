locals {
  match_labels = {
    "app.kubernetes.io/name"       = var.name
    "app.kubernetes.io/managed-by" = "terraform"
    "app.kubernetes.io/component"  = "app"
  }
  # Empty list == false, one-item list == true. Easier to use with `for_each`
  enable_litestream      = var.sqlite_replicate != null ? toset(["enabled"]) : toset([])
  litestream_image       = "litestream/litestream:0.3"
  litestream_config_path = "/etc/litestream.yml"
  data_volume            = "application-state"
  config_volume          = "litestream-config"
}

resource "kubernetes_config_map_v1" "litestream_config" {
  for_each = local.enable_litestream

  metadata {
    name      = "${var.name}-litestream-config"
    namespace = var.namespace
  }

  data = {
    # This DOES support multiple databases and multiple replicas per DB...
    # https://litestream.io/reference/config/#database-settings
    basename(local.litestream_config_path) = yamlencode({
      logging = {
        level  = "info"
        type   = "json"
        stderr = false
      }
      dbs = [{
        path = var.sqlite_replicate.file_path,
        replicas = [{
          type        = "s3"
          endpoint    = var.sqlite_replicate.s3_endpoint
          skip-verify = true
          bucket      = var.sqlite_replicate.s3_bucket
          path        = var.name
        }]
      }]
    })
  }
}

moved {
  # We want this to be optional, so we use `for_each` and do it 0 times when we don't need it.
  # This also means that to access it, we need to use the key from the iteration.
  from = kubernetes_config_map_v1.litestream_config
  to   = kubernetes_config_map_v1.litestream_config["enabled"]
}

resource "kubernetes_deployment" "app" {
  metadata {
    name      = var.name
    namespace = var.namespace
    labels = {
      "homeserver.lknuth.dev/sqlite-replicated" = var.sqlite_replicate != null ? "true" : "false"
    }
  }

  spec {
    # NOTE: Litestream does NOT support more than one replica atm.
    replicas = 1

    selector {
      match_labels = local.match_labels
    }

    template {
      metadata {
        labels = local.match_labels
      }

      spec {
        dynamic "security_context" {
          # Use a consistent Group for all Containers to avoid root-containers fucking
          # permissions for non-root containers.
          for_each = try(var.sqlite_replicate.file_gid, null) != null ? [1] : []
          content {
            fs_group = var.sqlite_replicate.file_gid
          }
        }

        dynamic "volume" {
          for_each = local.enable_litestream
          content {
            name = local.config_volume
            config_map {
              name = kubernetes_config_map_v1.litestream_config["enabled"].metadata.0.name
            }
          }
        }

        dynamic "volume" {
          for_each = local.enable_litestream
          content {
            name = local.data_volume
            # TODO Litestream says we _should_ use a PVC...
            empty_dir {}
          }
        }

        # Litestream Init Restore from Snapshot
        dynamic "init_container" {
          for_each = local.enable_litestream
          content {
            name  = "litestream-restore-snapshot"
            image = local.litestream_image
            args = [
              "restore",
              "-if-db-not-exists",
              "-if-replica-exists",
              var.sqlite_replicate.file_path
            ]

            security_context {
              run_as_user  = var.sqlite_replicate.file_uid
              run_as_group = var.sqlite_replicate.file_gid
            }

            volume_mount {
              name       = local.config_volume
              mount_path = local.litestream_config_path
              sub_path   = basename(local.litestream_config_path)
            }

            volume_mount {
              name       = local.data_volume
              mount_path = dirname(var.sqlite_replicate.file_path)
            }

            env_from {
              secret_ref {
                name = var.sqlite_replicate.s3_secret_name
              }
            }
          }
        }

        # Litestream Sidecar
        dynamic "container" {
          for_each = local.enable_litestream
          content {
            name  = "litestream-sidecar"
            image = local.litestream_image
            args  = ["replicate"]

            security_context {
              run_as_user  = var.sqlite_replicate.file_uid
              run_as_group = var.sqlite_replicate.file_gid
            }

            volume_mount {
              name       = local.config_volume
              mount_path = local.litestream_config_path
              sub_path   = basename(local.litestream_config_path)
            }

            volume_mount {
              name       = local.data_volume
              mount_path = dirname(var.sqlite_replicate.file_path)
            }

            env_from {
              secret_ref {
                name = var.sqlite_replicate.s3_secret_name
              }
            }
          }
        }

        # Web App Container
        container {
          name  = var.name
          image = var.image

          dynamic "env" {
            for_each = var.env
            content {
              name  = env.key
              value = tostring(env.value)
            }
          }

          dynamic "volume_mount" {
            for_each = local.enable_litestream
            content {
              name       = local.data_volume
              mount_path = dirname(var.sqlite_replicate.file_path)
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
    annotations = merge({
      "gethomepage.dev/enabled" = true
      "gethomepage.dev/group"   = "Apps"
    }, var.dashboard_attributes)
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
