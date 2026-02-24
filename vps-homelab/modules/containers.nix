{
  ...
}:

let
  quadlets = [
    ./container/whoami.nix
    ./container/traefik.nix
  ];
in
{
  # Binding to port 80
  boot.kernel.sysctl."net.ipv4.ip_unprivileged_port_start" = 80;
  # services = {
  #   dnsmasq = {
  #     enable = true;
  #     settings = {
  #       address = "/.${config.networking.hostName}/127.0.0.1";
  #     };
  #   };
  #   resolved = {
  #     enable = true;
  #     settings.Resolve.DNSStubListener = "no";
  #   };
  # };

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
    uid = 1001;
    linger = true;
    autoSubUidGidRange = true;
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
      ]
      ++ quadlets;
    };
}
