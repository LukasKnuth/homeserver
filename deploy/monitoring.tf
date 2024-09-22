resource "kubernetes_namespace" "monit" {
  metadata {
    name = "monitoring"
    labels = {
      # This is required here to allow Pods _inside_ the namespace 
      # to mount host-paths contianing container log files.
      "pod-security.kubernetes.io/enforce" = "privileged"
    }
  }
}

resource "gotify_application" "diun" {
  depends_on = [module.ingress, module.gotify]

  name        = "Diun"
  description = "Checks cluster containers for image updates."
}

module "container_images" {
  source    = "./updates"
  namespace = kubernetes_namespace.monit.metadata.0.name
  observe_namespaces = [
    kubernetes_namespace.apps.metadata.0.name,
    kubernetes_namespace.infra.metadata.0.name,
    kubernetes_namespace.monit.metadata.0.name
  ]
  cron_schedule            = "0 3 * * *"
  gotify_endpoint          = module.gotify.internal_service_url
  gotify_application_token = gotify_application.diun.token
}

resource "gotify_application" "log_analysis_problems" {
  name        = "Log Analysis"
  description = "Problems found by analyzing container logs"
}

resource "gotify_plugin" "slack_webhook" {
  module_path = "github.com/LukasKnuth/gotify-slack-webhook"
  enabled     = true
}

module "logs" {
  source               = "./logs"
  namespace            = kubernetes_namespace.monit.metadata.0.name
  gotify_slack_webhook = "${module.gotify.internal_service_url}${gotify_plugin.slack_webhook.webhook_path}/webhook/slack/${gotify_application.log_analysis_problems.token}"
}
