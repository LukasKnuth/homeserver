locals {
  slack_webhook = provider::netparse::parse_url(var.gotify_slack_webhook)
}

# Most details are stolen from the official Helm chart over at:
# https://github.com/fluent/helm-charts/blob/642a95978ea469d4bf66e233a29fbf29f80572cc/charts/fluent-bit/values.yaml#L458
resource "kubernetes_config_map" "fluent_bit" {
  metadata {
    name      = "fluent-bit"
    namespace = var.namespace
  }

  data = {
    # Find problems with Litestream replication and raise them
    "out_gotify.conf"    = <<-EOF
    [FILTER]
      Name grep
      Alias litestream-replicate
      Match kubernetes.*
      Logical_Op and
      Regex $kubernetes['container_name'] litestream-(sidecar|restore-snapshot)

    [FILTER]
      Name rewrite_tag
      Match kubernetes.*
      Alias litestream-replication-problems
      Rule $level ^(WARN|ERROR)$ problem.$TAG true

    [OUTPUT]
      Name stdout
      Alias stdout
      Match kubernetes.*
      Format json_lines

    [OUTPUT]
      Name slack
      Alias gotify
      Match problem.*
      # "slack" output requires URL to have HTTPS schema, but we don't have/want certs
      # Send HTTPS traffic to HTTP endpoint - but its okay, we disable TLS verification
      # https://docs.fluentbit.io/manual/administration/transport-security
      Webhook https://${local.slack_webhook.host}:80${local.slack_webhook.path}
      tls Off
    EOF
    "in_kubernetes.conf" = <<-EOF
    [INPUT]
      Name tail
      Alias kubernetes
      Path /var/log/containers/*.log
      Parser containerd
      Tag kubernetes.*

    [FILTER]
      Name kubernetes
      Alias kubernetes
      Match kubernetes.*
      Kube_Tag_Prefix kubernetes.var.log.containers.
      Use_Kubelet Off
      Merge_Log On
      Merge_Log_Trim On
      Keep_Log Off
      K8S-Logging.Parser Off
      K8S-Logging.Exclude On
      Annotations Off
      Labels On

    [FILTER]
      Name modify
      Match kubernetes.*
      Add source kubernetes
      Remove logtag
    EOF
    # Stolen from https://www.talos.dev/v1.7/talos-guides/configuration/logging/
    "custom_parsers.conf" = <<-EOF
    [PARSER]
      Name containerd
      Format regex
      Regex ^(?<time>[^ ]+) (?<stream>stdout|stderr) (?<logtag>[^ ]*) (?<log>.*)$
      Time_Key time
      Time_Format %Y-%m-%dT%H:%M:%S.%L%z
    EOF
    # Main config, tailing kubernetes logs and enriching with Kubernetes API metadata
    "main.conf" = <<-EOF
    [SERVICE]
      Daemon Off
      Flush 5
      Log_Level info
      Parsers_File custom_parsers.conf
      HTTP_Server On
      HTTP_Listen 0.0.0.0
      HTTP_Port ${local.http_port}
      Health_Check On

    @INCLUDE in_kubernetes.conf
    @INCLUDE out_gotify.conf
    EOF
  }
}

resource "kubernetes_daemon_set_v1" "fluent_bit" {
  metadata {
    name      = "fluent-bit"
    namespace = var.namespace
  }

  spec {
    selector {
      match_labels = local.match_labels
    }

    template {
      metadata {
        labels = local.match_labels
        annotations = {
          "fluentbit.io/exclude" = true
        }
      }

      spec {
        service_account_name = kubernetes_service_account.fluent_bit.metadata.0.name

        volume {
          name = "config"
          config_map {
            name = kubernetes_config_map.fluent_bit.metadata.0.name
          }
        }

        # Container Logfiles access. NOTE: This requires the elevated privileges.
        volume {
          name = "logs"
          host_path {
            path = local.logs_path
          }
        }

        container {
          name  = "fluent-bit"
          image = "cr.fluentbit.io/fluent/fluent-bit"
          args = [
            "--workdir=/fluent-bit/etc",
            "--config=/fluent-bit/etc/conf/main.conf"
          ]

          volume_mount {
            name       = "config"
            mount_path = "/fluent-bit/etc/conf"
          }

          volume_mount {
            name       = "logs"
            mount_path = local.logs_path
          }

          port {
            container_port = local.http_port
            name           = "http"
          }

          liveness_probe {
            http_get {
              path = "/"
              port = "http"
            }
          }

          readiness_probe {
            http_get {
              path = "/api/v1/health"
              port = "http"
            }
          }
        }
      }
    }
  }
}

locals {
  match_labels = {
    "app.kubernetes.io/name"       = "fluent-bit"
    "app.kubernetes.io/managed-by" = "terraform"
    "app.kubernetes.io/component"  = "monitoring"
  }
  http_port = 2020
  logs_path = "/var/log"
}

resource "kubernetes_service_account" "fluent_bit" {
  metadata {
    name      = "fluent-bit"
    namespace = var.namespace
  }
}

resource "kubernetes_cluster_role" "rbac" {
  metadata {
    name = "fluent-bit"
  }

  rule {
    api_groups = [""]
    resources  = ["namespaces", "pods"]
    verbs      = ["get", "list", "watch"]
  }
}

resource "kubernetes_cluster_role_binding" "rbac" {
  metadata {
    name = "fluent-bit"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.rbac.metadata.0.name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.fluent_bit.metadata.0.name
    namespace = var.namespace
  }
}

