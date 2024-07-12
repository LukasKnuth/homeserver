resource "kubernetes_namespace" "monit" {
  metadata {
    name = "monitoring"
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
