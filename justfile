set shell := ["bash", "-uc"]

[group('talos')]
gen-secrets:
  talosctl gen secrets

[group('talos')]
gen-config machine-patch cluster-name="home_cgn" cluster-endpoint="https://${CLUSTER_STATIC_IP_V4}:6443":
  -talosctl gen config {{cluster-name}} {{cluster-endpoint}} --output-types talosconfig --with-secrets secrets.yaml
  talosctl gen config {{cluster-name}} {{cluster-endpoint}} --with-docs=false --with-examples=false --output-types controlplane --force --config-patch {{machine-patch}} --with-secrets secrets.yaml --config-patch @talos/patches/dns.yaml
  talosctl validate -c controlplane.yaml -m metal

[group('talos')]
apply-config ip insecure="false":
  talosctl apply-config -n {{ip}} -e {{ip}} {{ if insecure == "insecure" { "--insecure" } else {""} }} -f controlplane.yaml

[group('talos')]
update-config ip:
  talosctl --talosconfig ./talosconfig config endpoints "{{ip}}"
  talosctl --talosconfig ./talosconfig config nodes "{{ip}}"

[group('talos')]
bootstrap ip:
  talosctl bootstrap -n {{ip}} -e {{ip}}

[group('talos')]
kubeconfig:
  talosctl kubeconfig ./kubeconfig

[group('talos')]
upgrade ip version:
  # NOTE: Ensure this is the right version to upgrade _with_ (should be fine usually)
  talosctl upgrade --preserve --nodes {{ip}} --image "ghcr.io/siderolabs/installer:{{version}}"

terraform-folder := "./deploy"

[group('ci-cd')]
deploy:
  terraform -chdir={{terraform-folder}} apply

[group('ci-cd')]
init:
  terraform -chdir={{terraform-folder}} init

[group('ci-cd')]
plan:
  terraform -chdir={{terraform-folder}} plan

[group('ci-cd')]
tf-upgrade:
  terraform -chdir={{terraform-folder}} init -upgrade

[group('1password')]
op-service-account:
  op service-account create "home_cgn_cluster" --vault $TF_VAR_onepassword_vault_id:read_items
