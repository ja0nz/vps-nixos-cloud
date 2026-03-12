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

  name = "traefik";
  domain = "Host(`${name}.${vars.DOMAIN}`)";
in
{
  virtualisation.quadlet.containers.traefik = {
    containerConfig = {
      image = "traefik:latest";
      publishPorts = [
        "80:80"
      ];
      networks = publicNetworkNames;
      volumes = [
        "/run/user/${uid}/podman/podman.sock:/var/run/docker.sock:ro"
      ];
      labels = {
        "traefik.enable" = "true";
        "traefik.http.routers.${name}.rule" = domain;
        "traefik.http.routers.${name}.service" = "api@internal";
      };
      exec = [
        "--api=true"
        "--providers.docker=true"
        "--providers.docker.endpoint=unix:///var/run/docker.sock"
        "--providers.docker.exposedbydefault=false"
        "--entrypoints.web.address=:80"
      ];
    };
  };
}
