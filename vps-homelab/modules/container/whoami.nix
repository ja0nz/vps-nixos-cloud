{
  vars,
  ...
}:

let
  name = "whoami";
  containerPort = "3993";
  domain = "Host(`${name}.${vars.DOMAIN}`)";
in
{
  virtualisation.quadlet.containers.${name} = {
    containerConfig = {
      image = "docker.io/traefik/whoami:latest";
      dropCapabilities = [ "ALL" ];
      addCapabilities = [ ];
      noNewPrivileges = true;
      environments.WHOAMI_PORT_NUMBER = containerPort;
      networks = [ "podman" ];
      labels = {
        "traefik.enable" = "true";
        "traefik.http.routers.${name}.rule" = domain;
        "traefik.http.services.${name}.loadbalancer.server.port" = containerPort;
      };
    };
  };
}
