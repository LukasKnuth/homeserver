resource "kubernetes_namespace" "infra" {
  metadata {
    name = "infra"
    labels = {
      # This is required here to allow Pods _inside_ the namespace to:
      # - mount host-paths contianing container log files.
      # - listen on low-number ports.
      "pod-security.kubernetes.io/enforce" = "privileged"
    }
  }
}

module "ingress" {
  source    = "./ingress"
  namespace = kubernetes_namespace.infra.metadata.0.name
}

module "dns" {
  source    = "./dns"
  namespace = kubernetes_namespace.infra.metadata.0.name
  target_ip = var.cluster_static_ip
}

resource "gotify_application" "diun" {
  depends_on = [module.ingress, module.gotify]

  name        = "Diun"
  description = "Checks cluster containers for image updates."
}

module "container_images" {
  source    = "./updates"
  namespace = kubernetes_namespace.infra.metadata.0.name
  observe_namespaces = [
    kubernetes_namespace.apps.metadata.0.name,
    kubernetes_namespace.infra.metadata.0.name
  ]
  cron_schedule            = "0 3 * * *"
  gotify_endpoint          = module.gotify.internal_service_url
  gotify_application_token = gotify_application.diun.token
}

resource "gotify_application" "log_analysis_problems" {
  depends_on = [module.ingress, module.gotify]

  name        = "Log Analysis"
  description = "Problems found by analyzing container logs"
}

resource "gotify_plugin" "slack_webhook" {
  depends_on = [module.ingress, module.gotify]

  module_path = "github.com/LukasKnuth/gotify-slack-webhook"
  enabled     = true
}

module "logs" {
  source               = "./logs"
  namespace            = kubernetes_namespace.infra.metadata.0.name
  gotify_slack_webhook = "${module.gotify.internal_service_url}${gotify_plugin.slack_webhook.webhook_path}/webhook/slack/${gotify_application.log_analysis_problems.token}"
}

# Refactoring
moved {
  from = kubernetes_cluster_role.traefik-rbac
  to   = module.ingress.kubernetes_cluster_role.traefik-rbac
}
moved {
  from = kubernetes_cluster_role_binding.traefik-rbac
  to   = module.ingress.kubernetes_cluster_role_binding.traefik-rbac
}
moved {
  from = kubernetes_deployment.traefik
  to   = module.ingress.kubernetes_deployment.traefik
}
moved {
  from = kubernetes_ingress_class.traefik
  to   = module.ingress.kubernetes_ingress_class.traefik
}
moved {
  from = kubernetes_ingress_v1.traefik_dashboard
  to   = module.ingress.kubernetes_ingress_v1.traefik_dashboard
}
moved {
  from = kubernetes_service.traefik_dashboard
  to   = module.ingress.kubernetes_service.traefik_dashboard
}
moved {
  from = kubernetes_service_account.traefik
  to   = module.ingress.kubernetes_service_account.traefik
}

