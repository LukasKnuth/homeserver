locals {
  namespace = "apps"
}

resource "kubernetes_namespace" "apps" {
  metadata {
    name = local.namespace
  }
}

module "testapp" {
  source      = "./modules/stateful_web_app"
  name        = "wallabag"
  namespace   = local.namespace
  image       = "wallabag/wallabag:2.6.9"
  expose_port = 80
  env = {
    "SYMFONY__ENV__DOMAIN_NAME"     = "http://wallabag.rpi"
    "SYMFONY__ENV__DATABASE_DRIVER" = "pdo_sqlite"
  }
  fqdn           = "wallabag.rpi"
  sqlite_path    = "/opt/wallabag/data/wallabag.sqlite"
  s3_secret_name = kubernetes_secret_v1.litestream_config.metadata.0.name
  s3_url         = minio_s3_bucket.litestream_destination.bucket
}

