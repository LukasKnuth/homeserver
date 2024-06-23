set shell := ["bash", "-uc"]

# NixOS SD Image
rpi-image-file := "nixos-rpi.img"

rpi-image-build:
  docker run --rm -v $(pwd)/host_system:/workdir -w="/workdir" nixos/nix bash -c "nix-build '<nixpkgs/nixos>' -I nixos-config=sdImage.nix -A config.system.build.sdImage && cp -L result {{rpi-image-file}} && rm result"

# Nix Docker Containers
docker-image-file := "image.tar.gz"
docker-image-name := "backup-util"
docker-image-tag := "latest"
docker-repo-user := "LukasKnuth"
docker-repo-name := "ghcr.io" / lowercase(docker-repo-user) / docker-image-name

docker-build-image:
  docker run --rm -v $(pwd)/utility:/workdir -w="/workdir" nixos/nix bash -c "rm {{docker-image-file}}; nix-build && cp -L result {{docker-image-file}} && rm result"

docker-load-image:
  docker load < utility/{{docker-image-file}}

docker-remove-image:
  -docker rmi {{docker-image-name}}

docker-retag-image tag:
  docker tag {{docker-image-name}}:{{docker-image-tag}} {{docker-repo-name}}:{{tag}}

docker-push-image tag:
  docker login ghcr.io -u {{docker-repo-user}} -p {{env_var('GITHUB_TOKEN')}}
  docker push {{docker-repo-name}}:{{tag}}

docker-reimport-image: docker-remove-image docker-load-image
docker-full: docker-build-image docker-reimport-image
docker-publish tag: (docker-retag-image tag) (docker-push-image tag)

docker-run arg="version":
  docker run -it --rm {{docker-image-name}} -- {{arg}}

nix-container:
  docker run -it --rm -v $(pwd):/workdir -w="/workdir" nixos/nix

# Fetch K3s kubeconfig file from the server
fetch-kubeconfig ip user="pi":
  k3sup install --skip-install --ip {{ip}} --user {{user}}

# Get these from: https://start.1password.com/integrations/connect
create-1password-secret cred-file namespace="onepassword" secret-name="onepassword-credentials" key-name="onepassword-credentials":
  kubectl -n {{namespace}} create secret generic {{secret-name}} --from-literal={{key-name}}=$(base64 -i {{cred-file}})

create-1password-token token namespace="onepassword" secret-name="onepassword-token" key-name="token":
  kubectl -n {{namespace}} create secret generic {{secret-name}} --from-literal={{key-name}}={{token}}

# todo Cluster setup

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
