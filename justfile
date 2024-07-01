set shell := ["bash", "-uc"]

# Talos OS
gen-secrets:
  talosctl gen secrets

gen-config machine-patch cluster-name="home_cgn" cluster-endpoint="https://192.168.107.3:6443":
  -talosctl gen config {{cluster-name}} {{cluster-endpoint}} --output-types talosconfig --with-secrets secrets.yaml
  talosctl gen config {{cluster-name}} {{cluster-endpoint}} --with-docs=false --with-examples=false --output-types controlplane --force --config-patch {{machine-patch}} --with-secrets secrets.yaml --config-patch @talos/patches/dns.yaml
  talosctl validate -c controlplane.yaml -m metal

apply-config ip insecure="false":
  talosctl apply-config -n {{ip}} -e {{ip}} {{ if insecure == "insecure" { "--insecure" } else {""} }} -f controlplane.yaml

update-config ip:
  talosctl --talosconfig ./talosconfig config endpoints "{{ip}}"
  talosctl --talosconfig ./talosconfig config nodes "{{ip}}"

bootstrap ip:
  talosctl bootstrap -n {{ip}} -e {{ip}}

kubeconfig:
  talosctl kubeconfig ./kubeconfig

terraform-folder := "./deploy"

deploy:
  terraform -chdir={{terraform-folder}} apply

init:
  terraform -chdir={{terraform-folder}} init

plan:
  terraform -chdir={{terraform-folder}} plan
