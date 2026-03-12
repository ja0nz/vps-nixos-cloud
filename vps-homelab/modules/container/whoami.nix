{
  vars,
  ...
}:

let
  name = "whoami";
  publicNet = "whoami-net";
  containerPort = "3993";
  domain = "Host(`${name}.${vars.DOMAIN}`)";
in
{

  virtualisation.quadlet.networks."${publicNet}" = { };
  virtualisation.quadlet.containers.${name} = {
    containerConfig = {
      image = "docker.io/traefik/whoami:latest";
      dropCapabilities = [ "ALL" ];
      addCapabilities = [ ];
      noNewPrivileges = true;
      environments.WHOAMI_PORT_NUMBER = containerPort;
      networks = [ "${publicNet}" ];
      labels = {
        "traefik.enable" = "true";
        "traefik.http.routers.${name}.rule" = domain;
        "traefik.http.services.${name}.loadbalancer.server.port" = containerPort;
      };
    };
  };
}
