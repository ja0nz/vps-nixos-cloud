{
  vars,
  config,
  ...
}:

let
  name = "vault";
  publicNet = "vault-net";
  dataDir = "vault-data";
  containerPort = "8080";
  domain = "Host(`${name}.${vars.DOMAIN}`)";
in
{
  sops.secrets."smtp_username" = { };
  sops.secrets."smtp_password" = { };
  sops.templates."vw.env" = {
    content = ''
      DOMAIN=https://${name}.${vars.DOMAIN}
      ROCKET_PORT=${containerPort}
      ENABLE_WEBSOCKET=true
      SIGNUPS_ALLOWED=false
      SHOW_PASSWORD_HINT=false
      LOG_LEVEL=warn
      DISABLE_ADMIN_TOKEN=true

      SMTP_HOST=mail.smtp2go.com
      SMTP_PORT=2525

      SMTP_FROM=${name}@${vars.DOMAIN}
      SMTP_FROM_NAME=${name}
      SMTP_USERNAME=${config.sops.placeholder."smtp_username"}
      SMTP_PASSWORD=${config.sops.placeholder."smtp_password"}
    '';
  };

  # Define pangolin public-resources
  # Options: ../containers.nix
  hmOpts.pangolin.blueprints."${name}" = {
    inherit name;
    full-domain = "${name}.${vars.DOMAIN}";
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
  virtualisation.quadlet.volumes."${dataDir}" = { };
  virtualisation.quadlet.containers.${name} = {
    containerConfig = {
      image = "ghcr.io/dani-garcia/vaultwarden:latest";
      dropCapabilities = [ "ALL" ];
      addCapabilities = [ ];
      noNewPrivileges = true;
      environmentFiles = [ config.sops.templates."vw.env".path ];
      networks = [ "${publicNet}" ];
      volumes = [
        "${dataDir}:/data"
      ];
      labels = {
        "traefik.enable" = "true";
        "traefik.http.routers.${name}.rule" = domain;
        "traefik.http.services.${name}.loadbalancer.server.port" = containerPort;
      };
    };
  };
}
