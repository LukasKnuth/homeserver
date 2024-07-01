locals {
  match_labels = {
    app      = "external-coredns"
    function = "dns"
  }
  config_mount = "config"
  config_path  = "/etc/coredns/Corefile"
  db_path      = "/etc/coredns/db.rpi"
}

resource "kubernetes_config_map_v1" "dns_config" {
  metadata {
    name      = "external-coredns-config"
    namespace = var.namespace
  }

  data = {
    basename(local.config_path) = <<-EOT
    rpi {
      file ${local.db_path} {
        reload 0
      }
    }
    
    . {
      health
      ready
      forward . tls://9.9.9.9 {
        tls_servername dns.quad9.net
        health_check 5s
      }
      cache 30
    }
    EOT

    basename(local.db_path) = <<-EOT
    $ORIGIN rpi.
    @ 3600 IN SOA @ me.lknuth.dev. ( 2024070102 7200 3600 1209600 3600 )
    @ 3600 IN NS ns
    * 3600 IN A ${var.target_ip}
    EOT
  }
}

resource "kubernetes_deployment" "dns_server" {
  metadata {
    name      = "external-dns-server"
    namespace = var.namespace
  }

  spec {
    replicas = 1
    strategy {
      # Can't do rolling updates because we're binding to port 53 on the node, which
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
        volume {
          name = local.config_mount
          config_map {
            name = kubernetes_config_map_v1.dns_config.metadata.0.name
          }
        }

        container {
          name  = "dns"
          image = "coredns/coredns:1.11.1"
          args  = ["-conf", local.config_path]

          volume_mount {
            name       = local.config_mount
            mount_path = local.config_path
            sub_path   = basename(local.config_path)
          }

          volume_mount {
            name       = local.config_mount
            mount_path = local.db_path
            sub_path   = basename(local.db_path)
          }

          port {
            container_port = 53
            protocol       = "UDP"
            name           = "dns"
            # Expose this on the host directly.
            host_port = 53
          }

          port {
            container_port = 8080
            protocol       = "TCP"
            name           = "healthness"
          }

          liveness_probe {
            http_get {
              path   = "/health"
              port   = "healthness"
              scheme = "HTTP"
            }
          }

          port {
            container_port = 8181
            protocol       = "TCP"
            name           = "readiness"
          }

          readiness_probe {
            http_get {
              path   = "/ready"
              port   = "readiness"
              scheme = "HTTP"
            }
          }
        }
      }
    }
  }
}
