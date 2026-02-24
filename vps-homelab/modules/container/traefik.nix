{
  osConfig,
  ...
}:
let
  uid = toString osConfig.users.users.containers.uid;
in
{
  virtualisation.quadlet.containers.traefik = {
    containerConfig = {
      image = "traefik:latest";
      publishPorts = [
        "80:80"
        "8080:8080"
      ];
      networks = [ "podman" ];
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
