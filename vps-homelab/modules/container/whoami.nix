{
  vars,
  osConfig,
  ...
}:

let
  id = "whoami-server";
  subDomain = "whoami";
  publicNet = "whoami-net";
  containerPort = "3993";
  url = "Host(`${subDomain}.${vars.DOMAIN}`)";
in
{
  # Define pangolin public-resources
  # Options: ../containers.nix
  hmOpts.pangolin.blueprints."${id}" = {
    name = id;
    full-domain = "${subDomain}.${vars.DOMAIN}";
    protocol = "http";
    targets = [
      {
        hostname = "localhost";
        method = "http";
        port = 80;
      }
    ];
  };

  virtualisation.quadlet.networks."${publicNet}" = { };
  virtualisation.quadlet.containers.${id} = {
    containerConfig = {
      image = "docker.io/traefik/whoami:latest";
      dropCapabilities = [ "ALL" ];
      addCapabilities = [ ];
      noNewPrivileges = true;
      environments.TZ = osConfig.time.timeZone;
      environments.WHOAMI_PORT_NUMBER = containerPort;
      networks = [ "${publicNet}" ];
      labels = {
        "traefik.enable" = "true";
        "traefik.http.routers.${id}.rule" = url;
        "traefik.http.services.${id}.loadbalancer.server.port" = containerPort;
      };
    };
  };
}
