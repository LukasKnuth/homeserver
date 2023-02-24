# Mostly from https://github.com/NixOS/nixpkgs/blob/master/pkgs/build-support/docker/examples.nix
# https://github.com/moby/moby/blob/master/image/spec/v1.2.md#image-json-field-descriptions
# https://nixos.org/manual/nixpkgs/stable/#sec-pkgs-dockerTools

tag: { dockerTools, pkgs }:

let
  justfile = pkgs.writeText "justfile" ''
  set shell := ["bash", "-uc"]

  version:
    just --version
    restic version
    python3 --version
  
  shell:
    -bash
  
  restic-safe-init:
    #!/bin/bash
    restic snapshots
    if [ $? -ne 0 ]; then restic init; fi
  
  restic-backup:
    restic backup . --no-cache --host {{env_var('BACKUP_NAME')}}
  
  restic-retain:
    restic forget --host {{env_var('BACKUP_NAME')}} --keep-daily {{env_var('BACKUP_KEEP_DAILY')}} --keep-weekly {{env_var('BACKUP_KEEP_WEEKLY')}} --keep-monthly {{env_var('BACKUP_KEEP_MONTHLY')}}
  
  restic-prune:
    # actually remove the data - LOCKS the repo, can't make new backups!
    restic prune
    # verify integrity of reopsitory
    restic check
  
  backup: restic-safe-init restic-backup restic-retain

  healthcheck-io:
    #!/bin/python3
    import os, requests
    res = requests.post(os.environ['HEALTHCHECK_IO_URL'], timeout=10)
    res.raise_for_status()
  
  unifi-backup:
    #!/bin/python3
    import os, requests
    res = requests.post('https://unifi-controller.rpi/api/login', json={
      'username': os.environ['UNIFI_USERNAME'], 'password': os.environ['UNIFI_PASSWORD']
    }, verify=False)
    res.raise_for_status()
    print(res.url, res.status_code)
    cookies = res.cookies
    res = requests.post(
      'https://unifi-controller.rpi/api/s/{0}/cmd/backup'.format(os.environ.get('UNIFI_SITE', 'default')),
      json={'cmd': 'backup', 'days': 0}, cookies=cookies, verify=False
    )
    res.raise_for_status()
    print(res.url, res.status_code)
    download_url = res.json()['data'][0]['url']
    res = requests.get('https://unifi-controller.rpi{0}'.format(download_url),
      cookies=cookies, verify=False)
    res.raise_for_status()
    print(res.url, res.status_code)
    with open('unifi-backup.unf', 'wb') as fd:
      for chunk in res.iter_content(chunk_size=128):
        fd.write(chunk)
  '';
in dockerTools.buildImage {
  inherit tag;
  name = "backup-util";
  # just will write scripts to /tmp, so it must exist.
  extraCommands = "mkdir tmp";
  copyToRoot = pkgs.buildEnv {
    name = "image-root";
    pathsToLink = [ "/bin" ];
    paths = with pkgs; [
      tini bash coreutils restic just
      (python39.withPackages (p: [p.requests]))
    ];
  };
  config = {
    WorkingDir = "/workdir";
    Entrypoint = [ "${pkgs.tini}/bin/tini" "--" "${pkgs.just}/bin/just" "-f" justfile ];
    Cmd = [ "-l" ];
    Labels = {
      "org.opencontainers.image.source" = "https://github.com/LukasKnuth/homeserver";
      "org.opencontainers.image.description" = "Utility container mainly for creating backups of the cluster.";
      "org.opencontainers.image.licenses" = "GPL-3.0";
    };
  };
}
