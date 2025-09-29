resource "kubernetes_namespace" "apps" {
  metadata {
    name = "apps"
  }
}

module "dashboard" {
  source               = "./dashboard"
  namespace            = kubernetes_namespace.apps.metadata.0.name
  apps_namespace       = kubernetes_namespace.apps.metadata.0.name
  onepassword_vault_id = var.onepassword_vault_id
  bookmarks = {
    "At Work" : [
      ["Backend", "https://github.com/sevenmind/backend"],
      ["Kubernetes", "https://github.com/sevenmind/7mind-kubernetes"],
      ["APIv1", "https://github.com/sevenmind/7mind-api-v1"],
      ["Infrastructure", "https://github.com/sevenmind/infrastructure"],
      ["API Contracts", "https://github.com/sevenmind/api-contracts"],
      ["PubSub", "https://console.cloud.google.com/cloudpubsub?project=mind-f62c0"],
      ["Cluster", "https://console.cloud.google.com/kubernetes/clusters/details/europe-west3/eu/details?project=mind-f62c0"],
      ["Cloud SQL", "https://console.cloud.google.com/sql/instances?project=mind-f62c0"],
      ["Logs", "https://app.datadoghq.eu/logs"],
      ["Synthetics", "https://app.datadoghq.eu/synthetics/tests"],
      ["Traces", "https://app.datadoghq.eu/apm/traces"],
      ["Monitors", "https://app.datadoghq.eu/monitors/"],
      ["Architecture Meeting", "https://www.notion.so/7mind/Backend-Architecture-b9683cdf5eba4ae4a7fcf9d97327221d"],
      ["Maintenance Meeting", "https://linear.app/7mind/view/a2ba1524-ba24-4a02-b343-58c1fa25ab54"],
      ["Personio", "https://7nxt-gmbh.app.personio.com/"],
      ["Reimbursment", "https://portal.payhawk.com/"],
      ["Travel", "https://app.travelperk.com/"],
    ],
    "Based Tools" : [
      ["Excalidraw", "https://excalidraw.com"],
      ["Regex101", "https://regex101.com"],
      ["Seq Diagram", "https://www.websequencediagrams.com/app"],
      ["D2 Diagram", "https://play.d2lang.com"],
      ["Github Tokens", "https://github.com/settings/tokens"],
      ["LanguageTool", "https://languagetool.org/"],
      ["UUID Generator", "${module.devtools.external_service_url}/uuid-generator"],
      ["Base64 Coder", "${module.devtools.external_service_url}/base64-string-converter"],
      ["JWT Debugger", "${module.devtools.external_service_url}/jwt-parser"],
      ["Percentage Calc", "${module.devtools.external_service_url}/percentage-calculator"],
    ],
    "Daily Games" : [
      ["Framed", "https://framed.wtf"],
      ["Connections", "https://www.nytimes.com/games/connections"],
      ["Gaps", "https://gaps.wtf"],
      ["Wordle", "https://www.nytimes.com/games/wordle"],
      ["Bracket City", "https://www.theatlantic.com/games/bracket-city/"],
      ["keybr", "https://www.keybr.com/"],
      ["monkeytype", "https://monkeytype.com/"]
    ],
    Procrastinate : [
      ["HackerNews", "https://news.ycombinator.com"],
      ["Nebula", "https://nebula.tv"],
      ["Sliggy", "https://www.twitch.tv/sliggytv/videos"],
      ["Sideshow", "https://www.twitch.tv/sideshow/videos"],
      ["Supertf", "https://www.twitch.tv/supertf/videos"],
      ["NorthernLion", "https://www.twitch.tv/northernlion/videos"],
    ]
  }
}

moved {
  from = module.testapp
  to   = module.wallabag
}
module "wallabag" {
  source      = "./modules/web_app"
  name        = "wallabag"
  namespace   = kubernetes_namespace.apps.metadata.0.name
  image       = "wallabag/wallabag:2.6.13"
  expose_port = 80
  env = {
    "SYMFONY__ENV__DOMAIN_NAME"     = "http://wallabag.rpi"
    "SYMFONY__ENV__DATABASE_DRIVER" = "pdo_sqlite"
  }
  dashboard_attributes = {
    "gethomepage.dev/name" = "Articles"
  }
  fqdn = "wallabag.rpi"
  sqlite_replicate = {
    file_path      = "/var/www/wallabag/data/db/wallabag.sqlite"
    file_uid       = 65534 # user "nobody"
    file_gid       = 65534 # group "nobody"
    s3_secret_name = kubernetes_secret_v1.litestream_config.metadata.0.name
    s3_bucket      = minio_s3_bucket.litestream_destination.bucket
    s3_endpoint    = var.s3_endpoint
    verify_cron    = "0 2 * * 6" # 02:00 on Saturday
  }
}

module "nocodb" {
  source    = "./modules/web_app"
  name      = "nocodb"
  namespace = kubernetes_namespace.apps.metadata.0.name
  image     = "nocodb/nocodb:0.264.4"
  env = {
    "NC_DISABLE_ERR_REPORT" = "true"
    "NC_DISABLE_TELE"       = "true"
  }
  dashboard_attributes = {
    "gethomepage.dev/name" = "Tables"
  }
  expose_port        = 8080
  liveness_get_path  = "/api/v1/health"
  readiness_get_path = "/api/v1/health"
  fqdn               = "nocodb.rpi"
  sqlite_replicate = {
    file_path      = "/usr/app/data/noco.db"
    s3_secret_name = kubernetes_secret_v1.litestream_config.metadata.0.name
    s3_bucket      = minio_s3_bucket.litestream_destination.bucket
    s3_endpoint    = var.s3_endpoint
    verify_cron    = "20 2 * * 6" # 02:20 on Saturday
  }
}

resource "gotify_client" "dashboard" {
  name = "Dashboard Widget"
}

locals {
  gotify_db_path = "/app/database/gotify.db"
}

module "gotify" {
  source    = "./modules/web_app"
  name      = "gotify"
  namespace = kubernetes_namespace.apps.metadata.0.name
  image     = "ghcr.io/lukasknuth/gotify-slack-webhook-bundled:v0.1.1"
  env = {
    "GOTIFY_REGISTRATION"               = true
    "TZ"                                = "Europe/Berlin"
    "GOTIFY_SERVER_SSL_ENABLED"         = false
    "GOTIFY_SERVER_SSL_REDIRECTTOHTTPS" = false
    "GOTIFY_DATABASE_DIALECT"           = "sqlite3"
    # Using a different path here because the mount can't overlay `/app/data/plugins`
    # otherwise the bundled plugins can't be found.
    "GOTIFY_DATABASE_CONNECTION" = local.gotify_db_path
  }
  dashboard_attributes = {
    "gethomepage.dev/name"          = "Gotify"
    "gethomepage.dev/group"         = "Infra"
    "gethomepage.dev/widget.type"   = "gotify"
    "gethomepage.dev/widget.fields" = "[\"messages\"]"
    # NOTE change this if either name, namespace or expose_port change!
    "gethomepage.dev/widget.url" = "http://gotify.apps.svc.cluster.local"
    "gethomepage.dev/widget.key" = gotify_client.dashboard.token
  }
  expose_port        = 80
  readiness_get_path = "/health"
  liveness_get_path  = "/health"
  fqdn               = "gotify.rpi"
  sqlite_replicate = {
    file_path      = local.gotify_db_path
    s3_secret_name = kubernetes_secret_v1.litestream_config.metadata.0.name
    s3_bucket      = minio_s3_bucket.litestream_destination.bucket
    s3_endpoint    = var.s3_endpoint
    verify_cron    = "40 2 * * 6" # 02:40 on Saturday
  }
}

module "notes" {
  source = "./modules/web_app"
  # NOTE: Can't just be memos, see https://github.com/usememos/memos/issues/1782#issuecomment-1576627426
  name      = "memos-notes"
  namespace = kubernetes_namespace.apps.metadata.0.name
  image     = "ghcr.io/usememos/memos:0.24.4"
  dashboard_attributes = {
    "gethomepage.dev/name" = "Diary"
  }
  env = {
    "MEMOS_PUBLIC" = true
  }
  expose_port = 5230
  fqdn        = "deardiary.rpi"
  sqlite_replicate = {
    file_path      = "/var/opt/memos/memos_prod.db"
    s3_secret_name = kubernetes_secret_v1.litestream_config.metadata.0.name
    s3_bucket      = minio_s3_bucket.litestream_destination.bucket
    s3_endpoint    = var.s3_endpoint
    verify_cron    = "0 3 * * 6" # 03:00 on Saturday
  }
}

module "devtools" {
  source    = "./modules/web_app"
  name      = "devtools"
  namespace = kubernetes_namespace.apps.metadata.0.name
  image     = "ghcr.io/corentinth/it-tools:2024.10.22-7ca5933"
  env = {
    "VITE_TRACKER_ENABLED" = false
  }
  dashboard_attributes = {
    "gethomepage.dev/name" = "Developer Tools"
  }
  expose_port = 80
  fqdn        = "devtools.rpi"
}

resource "kubernetes_config_map_v1" "news_feeds" {
  metadata {
    name      = "news-feeds"
    namespace = kubernetes_namespace.apps.metadata.0.name
  }
  data = {
    "feeds.yml" = yamlencode({
      feeds = [
        "https://bikepacking.com/news/readers-rig/feed/",
        "https://bytes.zone/index.xml",
        "https://xn--gckvb8fzb.com/index.xml",
        "https://claytonwramsey.com/blog/rss.xml",
        "https://jmswrnr.com/feed",
        "https://mtlynch.io/index.xml",
        "https://www.simplermachines.com/rss/",
        "https://shatterzone.substack.com/feed",
        "https://gieseanw.wordpress.com/feed/",
        "https://krebsonsecurity.com/feed/",
        "https://maggieappleton.com/rss.xml",
        "https://organizingmythoughts.org/rss/",
        "https://www.horrific-terrific.tech/feed",
        "https://xeiaso.net/blog.rss",
        "https://blog.habets.se/feed.xml",
        "https://fasterthanli.me/index.xml",
        "https://www.ccc.de/de/rss/updates.xml",
        "https://lostgarden.com/feed/",
        "https://alexkondov.com/rss.xml",
        "https://rosenzweig.io/feed.xml",
        "https://indiegamesplus.com/feed/",
        "https://solar.lowtechmagazine.com/posts/index.xml",
        "https://idiallo.com/feed.rss",
        "https://lwn.net/headlines/rss",
        { url = "https://lknuth.dev/writings/index.xml", group = "1. Review" },
        { url = "https://lknuth.dev/picks/index.xml", group = "1. Review" },
        { url = "https://www.technologyreview.com/feed", group = "3. News Tech" },
        { url = "https://www.tagesschau.de/ausland/europa/index~rss2.xml", group = "9. News DE" },
        { url = "https://www.tagesschau.de/investigativ/index~rss2.xml", group = "9. News DE" },
        { url = "https://netzpolitik.org/feed/", group = "9. News DE" }
      ]
    })
  }
}

module "briefly" {
  source    = "./modules/web_app"
  name      = "briefly"
  namespace = kubernetes_namespace.apps.metadata.0.name
  image     = "ghcr.io/lukasknuth/briefly:0.1.3"
  env = {
    "TZ"           = "Europe/Berlin"
    "CRON_REFRESH" = "30 7 * * *" # daily at 7:30am
  }
  config_map = {
    name       = kubernetes_config_map_v1.news_feeds.metadata.0.name
    mount_path = "/etc/briefly/"
  }
  dashboard_attributes = {
    "gethomepage.dev/name" = "Feed"
  }
  expose_port = 4000
  fqdn        = "feed.rpi"
}

