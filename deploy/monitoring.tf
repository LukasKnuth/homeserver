resource "kubernetes_namespace" "monit" {
  metadata {
    name = "monitoring"
  }
}

# TODO This runs the Request on EVERY apply. Creates a new API key every time and updates the config.... not what i wasnt
# TODO We _CAN_ make a request to a service without DNS being setup by setting the "Host" HTTP field manually...
data "http" "gotify_app_token" {
  depends_on = [module.gotify]

  url    = "${module.gotify.external_service_url}/application"
  method = "POST"
  request_headers = {
    "Authorization" = "Basic ${base64encode("admin:admin")}"
    "Content-Type"  = "application/json"
    "Accept"        = "application/json"
  }
  request_body = jsonencode({
    name        = "Diun"
    description = "Checks cluster containers for image updates."
  })

  lifecycle {
    postcondition {
      condition     = self.status_code == 200
      error_message = "Gotify REST API call failed: ${self.response_body}"
    }
  }
}

module "container_images" {
  source    = "./updates"
  namespace = kubernetes_namespace.monit.metadata.0.name
  observe_namespaces = [
    kubernetes_namespace.apps.metadata.0.name,
    kubernetes_namespace.infra.metadata.0.name,
    kubernetes_namespace.monit.metadata.0.name
  ]
  cron_schedule   = "0 3 * * *"
  gotify_endpoint = module.gotify.internal_service_url
  gotify_token    = jsondecode(data.http.gotify_app_token.response_body).token
}
