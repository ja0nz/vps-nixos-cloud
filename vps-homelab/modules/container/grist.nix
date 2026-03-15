{
  vars,
  config,
  osConfig,
  ...
}:

let
  # Common
  id = "grist-server";
  subDomain = "calc";
  publicNet = "grist-net";
  containerPort = "8484";
  url = "${subDomain}.${vars.DOMAIN}";
in
{
  sops.secrets."grist_session_password" = { };
  sops.templates."${id}.env" = {
    content = ''
      # https://support.getgrist.com/self-managed/
      APP_HOME_URL=https://${url}

      GRIST_DEFAULT_EMAIL=hey@ja.nz
      GRIST_DEFAULT_LOCALE=de-DE
      GRIST_LOG_LEVEL=warn
      GRIST_SANDBOX_FLAVOR=gvisor
      GRIST_SINGLE_ORG=immo
      GRIST_HIDE_UI_ELEMENTS=helpCenter,billing,templates,multiSite,multiAccounts,supportGrist,sendToDrive
      GRIST_FORCE_LOGIN=true
      GRIST_PAGE_TITLE_SUFFIX=
      GRIST_SESSION_SECRET=${config.sops.placeholder."grist_session_password"}

      # https://support.getgrist.com/install/oidc/
      # GRIST_OIDC_IDP_ISSUER=
      # GRIST_OIDC_IDP_CLIENT_ID=
      # GRIST_OIDC_IDP_CLIENT_SECRET=
      # GRIST_OIDC_IDP_END_SESSION_ENDPOINT=
    '';
  };

  # Define pangolin public-resources
  # Options: ../containers.nix
  hmOpts.pangolin.blueprints."${id}" = {
    name = id;
    full-domain = url;
    protocol = "http";
    auth = {
      sso-enabled = true;
    };
    targets = [
      {
        hostname = "localhost";
        method = "http";
        port = 80;
        healthcheck = {
          hostname = "localhost";
          port = 80;
          path = "/status";
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
      image = "docker.io/gristlabs/grist:latest";
      dropCapabilities = [ "ALL" ];
      addCapabilities = [
        "SETUID"
        "SETGID"
        "CHOWN"
        "DAC_OVERRIDE"
      ];
      noNewPrivileges = true;
      environmentFiles = [ config.sops.templates."${id}.env".path ];
      environments.TZ = osConfig.time.timeZone;
      networks = [
        "${publicNet}"
      ];
      volumes = [
        "${id}:/persist"
      ];
      labels = {
        "traefik.enable" = "true";
        "traefik.http.routers.${id}.rule" = "Host(`${url}`)";
        "traefik.http.services.${id}.loadbalancer.server.port" = containerPort;
      };
    };
  };
}
