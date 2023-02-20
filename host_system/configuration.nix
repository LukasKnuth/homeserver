{ pkgs, ...}:
let
  user = "pi";
  pw_hash = "$y$j9T$Jq4Y04HRjvA2zNEfRAixi1$e1t9BU8SNL9uqf.WpwK/4NXGQNmfv8V/.nU58Crq2JB";
  ssh_pub_keys = ["ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBpWELFg21EkpKxuC3bQ/D3YHEFn5RqLfTmtuifAu+a5 lukas@7mind.de"];
  host_name = "rpi";
  static_ip = "192.168.178.5";
  default_gateway = "192.168.178.1";
  default_nameserver = "192.168.178.1";
  rpi_hardware_git = {
    url = "https://github.com/NixOS/nixos-hardware.git";
    rev = "7c7a8f70827d55361b7def502f38b8757e09065f";
  };
in {
  # Get RPi specific hardware support.
  imports = [
    "${(builtins.fetchGit rpi_hardware_git)}/raspberry-pi/4"
  ];
  
  # Mount Root filesystem
  fileSystems = {
    "/" = {
      device = "/dev/disk/by-label/NIXOS_SD";
      fsType = "ext4";
      options = [ "noatime" ];
    };
  };

  # Kernel parameters for K3s
  # https://docs.k3s.io/advanced#raspberry-pi
  boot.kernelParams = [
    "cgroup_enable=cpuset"
    "cgroup_memory=1"
    "cgroup_enable=memory"
  ];

  # Locale Configuration
  time.timeZone = "Europe/Berlin";
  i18n.defaultLocale = "en_US.UTF-8";
  console.keyMap = "de";

  # Allow passwordless `sudo`
  security.sudo.wheelNeedsPassword = false;

  # Non-Root User
  users = {
    mutableUsers = false;
    users."${user}" = {
      isNormalUser = true;
      extraGroups = [ "wheel" "networkmanager" ];
      hashedPassword = pw_hash;
      openssh.authorizedKeys.keys = ssh_pub_keys;
    };
  };

  # Enable SSH Service
  services.openssh.enable = true;

  # Install packages
  environment.systemPackages = with pkgs; [ vim k3s git ];

  # K3s configuration
  services.k3s = {
    enable = true;
    role = "server";
    extraFlags = toString[
      # Installed through FluxCD from official Helm Chart
      "--disable=traefik"
    ];
  };

  # Network configuration
  networking.networkmanager.enable = true;

  # Set static network config
  networking = {
    interfaces.eth0.ipv4.addresses = [{
      address = static_ip;
      prefixLength = 24;
    }];
    defaultGateway = default_gateway;
    nameservers = [ default_nameserver ];
    hostName = host_name;
  };

  # Open ports in the firewall.
  networking.firewall.allowedTCPPorts = [
    10250   # Kubernetes Metric Server
    6443    # Kubernetes Control Plane
    80 443  # HTTP(s) access
    22      # SSH access
    53      # PiHole DNS
    8080    # Unifi-Controller Device Coms
  ];
  networking.firewall.allowedUDPPorts = [
    51820   # WireGuard
    53      # PiHole DNS
    3478    # Unifi Controller STUN
    10001   # Unifi Controller AP Discovery
  ];

  # The state this system was installed from
  system.stateVersion = "22.11";
}