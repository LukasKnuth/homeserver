terraform {
  # NOTE: Keep this secure, there are secrets in this config!
  cloud {
    organization = "LukasKnuth"

    workspaces {
      name = "home_cgn"
    }
  }
}
