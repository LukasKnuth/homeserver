output "internal_service_url" {
  value       = "http://${var.name}.${var.namespace}.svc.cluster.local:${var.expose_port}"
  description = "Base URL for calling the App from INSIDE the cluster"
}

output "external_service_url" {
  value       = "http://${var.fqdn}"
  description = "Base URL for calling this service from OUTSIDE the cluster"
}
