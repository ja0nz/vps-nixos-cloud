{
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
in
{
  virtualisation.quadlet.containers.traefik = {
    containerConfig = {
      image = "traefik:latest";
      publishPorts = [
        "80:80"
        "8080:8080"
      ];
      networks = publicNetworkNames;
      volumes = [
        "/run/user/${uid}/podman/podman.sock:/var/run/docker.sock:ro"
      ];
      exec = [
        "--api.insecure=true"
        "--providers.docker=true"
        "--providers.docker.exposedbydefault=false"
        "--entrypoints.web.address=:80"
      ];
    };
  };
}
