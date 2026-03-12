{
  vars,
  config,
  ...
}:

let
  name = "vault";
  containerPort = "80";
  domain = "Host(`${name}.${vars.DOMAIN}`)";
in
{

  sops.secrets."smtp_username" = { };
  sops.secrets."smtp_password" = { };
  sops.templates."vw.env" = {
    content = ''
      DOMAIN=https://${name}.${vars.DOMAIN}
      SIGNUPS_ALLOWED=false

      SMTP_HOST=mail.smtp2go.com
      SMTP_PORT=2525
      SMTP_FROM=${name}@${vars.DOMAIN}
      SMTP_FROM_NAME=${name}
      DISABLE_ADMIN_TOKEN=true
      SMTP_USERNAME=${config.sops.placeholder."smtp_username"}
      SMTP_PASSWORD==${config.sops.placeholder."smtp_password"}
    '';
  };

  virtualisation.quadlet.containers.${name} = {
    containerConfig = {
      image = "ghcr.io/dani-garcia/vaultwarden:latest";
      dropCapabilities = [ "ALL" ];
      addCapabilities = [ ];
      noNewPrivileges = true;
      environmentFiles = [ config.sops.templates."vw.env".path ];
      networks = [ "podman" ];
      labels = {
        "traefik.enable" = "true";
        "traefik.http.routers.${name}.rule" = domain;
        "traefik.http.services.${name}.loadbalancer.server.port" = containerPort;
      };
    };
  };
}
