{
  vars,
  config,
  osConfig,
  ...
}:

let
  id = "pocketid-auth";
  subDomain = "auth";
  publicNet = "auth-net";
  versionTag = "v2";
  containerPort = "1411";
  url = "${subDomain}.${vars.DOMAIN}";
in
{
  sops.secrets."pID_enc_key" = { };
  sops.templates."${id}.env" = {
    content = ''
      # https://pocket-id.org/docs/configuration/environment-variables
      APP_URL=https://${url}
      ENCRYPTION_KEY=${config.sops.placeholder."pID_enc_key"}
      TRUST_PROXY=true
    '';
  };

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
        healthcheck = {
          hostname = "localhost";
          port = 80;
          path = "/healthz";
          headers = [
            {
              name = "Host";
              value = url;
            }
          ];
        };
      }
    ];
  };

  virtualisation.quadlet.networks."${publicNet}" = { };
  virtualisation.quadlet.volumes."${id}" = { };
  virtualisation.quadlet.containers.${id} = {
    containerConfig = {
      image = "ghcr.io/pocket-id/pocket-id:${versionTag}";
      dropCapabilities = [ "ALL" ];
      addCapabilities = [
        "SETUID"
        "SETGID"
        "CHOWN"
      ];
      noNewPrivileges = true;
      environmentFiles = [ config.sops.templates."${id}.env".path ];
      environments.TZ = osConfig.time.timeZone;
      networks = [ "${publicNet}" ];
      volumes = [
        "${id}:/app/data"
      ];
      labels = {
        "traefik.enable" = "true";
        "traefik.http.routers.${id}.rule" = "Host(`${url}`)";
        "traefik.http.services.${id}.loadbalancer.server.port" = containerPort;
      };
    };
  };
}
