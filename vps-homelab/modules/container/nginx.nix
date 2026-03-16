{
  vars,
  pkgs,
  osConfig,
  ...
}:

let
  id = "nginx-server";
  srv = "/home/containers/docs/build";
  subDomain = "docs";
  publicNet = "nginx-net";
  containerPort = "80";
  url = "${subDomain}.${vars.DOMAIN}";
in
{
  # Define pangolin public-resources
  # Options: ../containers.nix
  hmOpts.pangolin.blueprints."${id}" = {
    name = id;
    full-domain = url;
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
  virtualisation.quadlet.volumes."${srv}" = {
    serviceConfig.ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p ${srv}";
  };
  virtualisation.quadlet.containers.${id} = {
    containerConfig = {
      image = "docker.io/nginx:stable";
      dropCapabilities = [ "ALL" ];
      addCapabilities = [ ];
      noNewPrivileges = true;
      environments.TZ = osConfig.time.timeZone;
      networks = [ "${publicNet}" ];
      volumes = [
        "/home/containers/docs/build:/usr/share/nginx/html:ro"
      ];
      labels = {
        "traefik.enable" = "true";
        "traefik.http.routers.${id}.rule" = "Host(`${url}`)";
        "traefik.http.services.${id}.loadbalancer.server.port" = containerPort;
      };
    };
  };
}
