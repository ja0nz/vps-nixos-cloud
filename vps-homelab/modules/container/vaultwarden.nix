{
  vars,
  config,
  osConfig,
  ...
}:

let
  id = "vaultwarden-server";
  subDomain = "vault";
  publicNet = "vault-net";
  containerPort = "8080";
  url = "Host(`${subDomain}.${vars.DOMAIN}`)";
in
{
  sops.secrets."smtp_username" = { };
  sops.secrets."smtp_password" = { };
  sops.templates."vw.env" = {
    content = ''
      DOMAIN=https://${subDomain}.${vars.DOMAIN}
      ROCKET_PORT=${containerPort}
      ENABLE_WEBSOCKET=true
      SIGNUPS_ALLOWED=false
      SHOW_PASSWORD_HINT=false
      LOG_LEVEL=warn
      DISABLE_ADMIN_TOKEN=true

      SMTP_HOST=mail.smtp2go.com
      SMTP_PORT=2525

      SMTP_FROM=${subDomain}@${vars.DOMAIN}
      SMTP_FROM_NAME=${subDomain}
      SMTP_USERNAME=${config.sops.placeholder."smtp_username"}
      SMTP_PASSWORD=${config.sops.placeholder."smtp_password"}
    '';
  };

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
      }
    ];
  };

  virtualisation.quadlet.networks."${publicNet}" = { };
  virtualisation.quadlet.volumes."${id}" = { };
  virtualisation.quadlet.containers.${id} = {
    containerConfig = {
      image = "ghcr.io/dani-garcia/vaultwarden:latest";
      dropCapabilities = [ "ALL" ];
      addCapabilities = [ ];
      noNewPrivileges = true;
      environmentFiles = [ config.sops.templates."vw.env".path ];
      environments.TZ = osConfig.time.timeZone;
      networks = [ "${publicNet}" ];
      volumes = [
        "${id}:/data"
      ];
      labels = {
        "traefik.enable" = "true";
        "traefik.http.routers.${id}.rule" = url;
        "traefik.http.services.${id}.loadbalancer.server.port" = containerPort;
      };
    };
  };
}
