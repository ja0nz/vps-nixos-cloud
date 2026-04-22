{
  vars,
  pkgs,
  config,
  osConfig,
  ...
}:

let
  id = "nginx-server";
  # Volumes is a custom symlink here!
  srv = "${config.home.homeDirectory}/volumes/${id}/docs/build";
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
  virtualisation.quadlet.volumes."${id}" = {
    serviceConfig = {
      Type = "oneshot";
      ExecStartPost = "${pkgs.coreutils}/bin/mkdir -p ${srv}";
    };
  };
  virtualisation.quadlet.containers.${id} = {
    containerConfig = {
      image = "docker.io/nginx:stable";
      dropCapabilities = [ "ALL" ];
      addCapabilities = [
        "SETUID"
        "SETGID"
        "CHOWN"
        "NET_BIND_SERVICE"
      ];
      noNewPrivileges = true;
      environments.TZ = osConfig.time.timeZone;
      networks = [ "${publicNet}" ];
      volumes = [
        "${srv}:/usr/share/nginx/html:ro"
      ];
      labels = {
        "traefik.enable" = "true";
        "traefik.http.routers.${id}.rule" = "Host(`${url}`)";
        "traefik.http.services.${id}.loadbalancer.server.port" = containerPort;
      };
    };
  };
}
