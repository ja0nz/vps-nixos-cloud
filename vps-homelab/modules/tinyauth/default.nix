{
  port,
  vars,
  ...
}:

let
  # --- CONFIG BLOCK ---
  cfg = {
    image = "ghcr.io/steveiliop56/tinyauth:v4";
    containerPort = "3000";
    hostPort = port.tinyauth;
    network = "podman";
    domain = "auth.${vars.DOMAIN}";
  };
in
{
  services.caddy.virtualHosts."${cfg.domain}" = {
    extraConfig = ''
      reverse_proxy localhost:${cfg.hostPort}
    '';
  };

  virtualisation.oci-containers.containers.tinyauth = {
    image = cfg.image;
    ports = [ "${cfg.hostPort}:${cfg.containerPort}" ];

    environment = {
      APP_URL = "https://${cfg.domain}";
      USERS = "enter:$2a$10$4Rt1s3w9UY31FhsfLY6ceuwh5tM9TvizWXrOruiLq377Duy852.vG";
    };

    networks = [ cfg.network ];
    autoStart = true;
    extraOptions = [
      "--security-opt=no-new-privileges"
    ];
  };
}
