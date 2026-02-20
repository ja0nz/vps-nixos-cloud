{
  port,
  vars,
  ...
}:

let
  # --- CONFIG BLOCK ---
  cfg = {
    image = "docker.io/traefik/whoami:latest";
    containerPort = "3993";
    hostPort = port.whoami;
    network = "podman";
    domain = "ping.${vars.DOMAIN}";
  };
in
{
  services.caddy.virtualHosts."${cfg.domain}" = {
    extraConfig = ''
      reverse_proxy localhost:${cfg.hostPort}
    '';
  };

  # TODO https://github.com/SEIAROTg/quadlet-nix/blob/f4ae60350ea6015b6560cbd0e1f11f7e195c993d/container.nix#L12
  # Follow up on this
  virtualisation.quadlet.containers.whoami = {
    containerConfig = {
      image = cfg.image;
      dropCapabilities = [ "ALL" ];
      addCapabilities = [ ];
      noNewPrivileges = true;
      publishPorts = [ "${cfg.hostPort}:${cfg.containerPort}" ];
      environments.WHOAMI_PORT_NUMBER = cfg.containerPort;
      networks = [ cfg.network ];
    };
  };
  # virtualisation.oci-containers.containers.whoami = {
  #   image = cfg.image;
  #   ports = [ "${cfg.hostPort}:${cfg.containerPort}" ];
  #   environment.WHOAMI_PORT_NUMBER = cfg.containerPort;
  #   networks = [ cfg.network ];
  #   extraOptions = [
  #     "--cap-drop=ALL"
  #     "--security-opt=no-new-privileges"
  #   ];
  # };
}
