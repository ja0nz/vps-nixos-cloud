{
  vars,
  osConfig,
  config,
  lib,
  ...
}:
let
  uid = toString osConfig.users.users.containers.uid;
  allNetworks = config.virtualisation.quadlet.networks;
  publicNetworks = lib.filterAttrs (_: net: (net.networkConfig.internal or null) != true) allNetworks;
  publicNetworkNames = lib.attrNames publicNetworks;

  id = "traefik-proxy";
  subDomain = "traefik";
  containerPort = "80";
  url = "${subDomain}.${vars.DOMAIN}";
in
{
  # Define pangolin public-resources
  # Options: ../containers.nix
  hmOpts.pangolin.blueprints."${id}" = {
    name = id;
    full-domain = "${subDomain}.${vars.DOMAIN}";
    protocol = "http";
    auth = {
      sso-enabled = true;
    };
    targets = [
      {
        hostname = "localhost";
        method = "http";
        port = 80;
        healthcheck = {
          hostname = "localhost";
          port = 80;
          path = "/ping";
        };
      }
    ];
  };

  virtualisation.quadlet.containers.${id} = {
    containerConfig = {
      image = "docker.io/traefik:latest";
      publishPorts = [
        "${containerPort}:${containerPort}"
      ];
      networks = publicNetworkNames;
      environments.TZ = osConfig.time.timeZone;
      volumes = [
        "/run/user/${uid}/podman/podman.sock:/var/run/docker.sock:ro"
      ];
      labels = {
        "traefik.enable" = "true";
        "traefik.http.routers.${id}.rule" = "Host(`${url}`)";
        "traefik.http.routers.${id}.service" = "api@internal";
      };
      exec = [
        "--api=true"
        "--ping=true"
        "--ping.entrypoint=web"
        "--providers.docker=true"
        "--providers.docker.endpoint=unix:///var/run/docker.sock"
        "--providers.docker.exposedbydefault=false"
        "--entrypoints.web.address=:${containerPort}"
      ];
    };
  };
}
