{
  pkgs,
  ...
}:

let
  quadlets = [
    ./container/whoami.nix
    ./container/vaultwarden.nix
    ./container/traefik.nix
  ];
  containersUID = 1001;
  containersAge = "/var/lib/containers-secrets/sops/age";
  dataDir = "/home/containers/.local/share/containers/storage/volumes";
in
{
  # Impermanence dependency
  # Either shared-modules/dev-opts.nix (stub) OR impermanence.nixosModules.impermanence
  environment.persistence."/persist" = {
    directories = [
      {
        directory = "${dataDir}";
        user = "containers";
        group = "users";
      }
    ];
  };

  # Binding to port 80
  # ./container/traefik.nix
  boot.kernel.sysctl."net.ipv4.ip_unprivileged_port_start" = 80;

  # Enable quadlet-nix
  virtualisation.quadlet = {
    enable = true;
    autoUpdate = {
      enable = true;
      calendar = "monthly";
    };
  };
  # Prune podman
  virtualisation.podman.autoPrune.enable = true;

  # Container runner
  users.users.containers = {
    isNormalUser = true;
    uid = containersUID;
    linger = true;
    autoSubUidGidRange = true;
  };

  # Derive age key from /etc/ssh/ssh_host_ed25519_key
  system.activationScripts.deriveContainersAgeKey = {
    text = ''
      mkdir -p ${containersAge}
      ${pkgs.ssh-to-age}/bin/ssh-to-age -private-key \
        -i /etc/ssh/ssh_host_ed25519_key \
        -o ${containersAge}/keys.txt
      chown -R ${toString containersUID} ${containersAge}
      chmod 600 ${containersAge}/keys.txt
    '';
    deps = [ "etc" ];
  };

  home-manager.users.containers =
    {
      inputs,
      osConfig,
      lib,
      ...
    }:

    {
      home.stateVersion = osConfig.system.stateVersion;
      systemd.user.services.podman-user-wait-network-online = {
        Install.WantedBy = lib.mkForce [ ];
      };

      imports = [
        inputs.quadlet-nix.homeManagerModules.quadlet
        inputs.sops-nix.homeManagerModules.sops
      ]
      ++ quadlets;

      # virtualisation.quadlet.networks = {
      #   immich-net-internal = {
      #     networkConfig = {
      #       internal = true;
      #     };
      #   };
      # };

      sops = {
        defaultSopsFormat = "yaml";
        defaultSopsFile = ../secrets/homelab.enc.yaml;
        age.keyFile = "${containersAge}/keys.txt";
      };
    };
}
