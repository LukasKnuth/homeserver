resource "kubernetes_namespace" "infra" {
  metadata {
    name = "infra"
    labels = {
      # This is required here to allow Pods _inside_ the namespace to listen to
      # low-number ports.
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

