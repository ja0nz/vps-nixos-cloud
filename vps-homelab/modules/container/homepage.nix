{
  vars,
  osConfig,
  ...
}:

let
  id = "homepage-server";
  publicNet = "homepage-net";
  containerPort = "3000";
in
{
  # Define pangolin public-resources
  # Options: ../containers.nix
  hmOpts.pangolin.blueprints."${id}" = {
    name = id;
    full-domain = vars.DOMAIN;
    protocol = "http";
    auth = {
      sso-enabled = true;
    };
    targets = [
      {
        hostname = "localhost";
        method = "http";
        port = 80;
      }
    ];
  };

  virtualisation.quadlet.networks."${publicNet}" = { };
  virtualisation.quadlet.volumes."${id}" = { };
  virtualisation.quadlet.containers.${id} = {
    containerConfig = {
      image = "ghcr.io/gethomepage/homepage:latest";
      dropCapabilities = [ "ALL" ];
      addCapabilities = [ ];
      noNewPrivileges = true;
      environments.TZ = osConfig.time.timeZone;
      environments.HOMEPAGE_ALLOWED_HOSTS = vars.DOMAIN;
      networks = [ "${publicNet}" ];
      volumes = [
        "${id}:/app/config"
      ];
      labels = {
        "traefik.enable" = "true";
        "traefik.http.routers.${id}.rule" = "Host(`${vars.DOMAIN}`)";
        "traefik.http.services.${id}.loadbalancer.server.port" = containerPort;
      };
    };
  };
}
