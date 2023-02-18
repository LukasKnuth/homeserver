set shell := ["bash", "-uc"]
# todo NixOS RaspberryPi Image

# Nix Docker Containers
nix-container:
  docker run -it --rm -v $(pwd)/utility:/workdir -w="/workdir" nixos/nix

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

# Fetch K3s kubeconfig file from the server
fetch-kubeconfig ip user="pi":
  k3sup install --skip-install --ip {{ip}} --user {{user}}

# Get these from: https://start.1password.com/integrations/connect
create-1password-secret cred-file namespace="onepassword" secret-name="onepassword-credentials" key-name="onepassword-credentials":
  kubectl -n {{namespace}} create secret generic {{secret-name}} --from-literal={{key-name}}=$(base64 -i {{cred-file}})

create-1password-token token namespace="onepassword" secret-name="onepassword-token" key-name="token":
  kubectl -n {{namespace}} create secret generic {{secret-name}} --from-literal={{key-name}}={{token}}

# todo Cluster setup
