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
  internalNet = "grist-internal-net";
  containerPort = "8484";
  url = "Host(`${subDomain}.${vars.DOMAIN}`)";

  # Database
  idDB = "grist-database";

  # Redis
  idRedis = "grist-redis";
in
{
  sops.secrets."grist_db_password" = { };
  sops.secrets."grist_session_password" = { };
  sops.templates."${id}.env" = {
    content = ''
      APP_HOME_URL=https://${subDomain}.${vars.DOMAIN}

      GRIST_DEFAULT_EMAIL=hey@ja.nz
      GRIST_DEFAULT_LOCALE=de-DE
      GRIST_LOG_LEVEL=warn
      GRIST_SANDBOX_FLAVOR=gvisor
      GRIST_SINGLE_ORG=immo
      GRIST_HIDE_UI_ELEMENTS=helpCenter,billing,templates,multiSite,multiAccounts,supportGrist,sendToDrive
      GRIST_FORCE_LOGIN=true
      GRIST_PAGE_TITLE_SUFFIX=
      GRIST_SESSION_SECRET=${config.sops.placeholder."grist_session_password"}

      REDIS_URL=redis://${idRedis}
      TYPEORM_TYPE=postgres
      TYPEORM_DATABASE=grist
      TYPEORM_USERNAME=grist
      TYPEORM_HOST=${idDB}
      TYPEORM_LOGGING=false
      TYPEORM_PASSWORD=${config.sops.placeholder."grist_db_password"}

      # GRIST_OIDC_IDP_ISSUER=
      # GRIST_OIDC_IDP_CLIENT_ID=
      # GRIST_OIDC_IDP_CLIENT_SECRET=
      # GRIST_OIDC_IDP_END_SESSION_ENDPOINT=
    '';
  };

  sops.templates."${idDB}.env" = {
    content = ''
      POSTGRES_DB=grist
      POSTGRES_USER=grist
      POSTGRES_INITDB_ARGS='--data-checksums'

      POSTGRES_PASSWORD=${config.sops.placeholder."grist_db_password"}
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
        healthcheck = {
          hostname = "localhost";
          port = 80;
          path = "/status";
        };
      }
    ];
  };

  virtualisation.quadlet.networks."${publicNet}" = { };
  virtualisation.quadlet.networks."${internalNet}" = {
    networkConfig = {
      internal = true;
    };
  };
  virtualisation.quadlet.volumes."${id}" = { };
  virtualisation.quadlet.containers.${id} = {
    unitConfig = {
      After = [
        "${idRedis}.service"
        "${idDB}.service"
      ];
      Requires = [
        "${idRedis}.service"
        "${idDB}.service"
      ];
    };
    containerConfig = {
      image = "docker.io/gristlabs/grist:latest";
      dropCapabilities = [ "ALL" ];
      addCapabilities = [
        "SETUID"
        "SETGID"
        "CHOWN"
        "FOWNER"
        "DAC_OVERRIDE"
      ];
      noNewPrivileges = true;
      environmentFiles = [ config.sops.templates."${id}.env".path ];
      environments.TZ = osConfig.time.timeZone;
      networks = [
        "${publicNet}"
        "${internalNet}"
      ];
      volumes = [
        "${id}:/persist"
      ];
      labels = {
        "traefik.enable" = "true";
        "traefik.http.routers.${id}.rule" = url;
        "traefik.http.services.${id}.loadbalancer.server.port" = containerPort;
      };
    };
  };

  virtualisation.quadlet.containers.${idRedis} = {
    containerConfig = {
      image = "docker.io/valkey/valkey:9";
      environments.TZ = osConfig.time.timeZone;
      networks = [ "${internalNet}" ];
      healthCmd = "valkey-cli ping | grep -q PONG";
      healthRetries = 2;
      healthInterval = "30s";
      healthTimeout = "10s";
      healthStartPeriod = "120s";
      healthStartupInterval = "5s";
    };
  };

  virtualisation.quadlet.volumes."${idDB}" = { };
  virtualisation.quadlet.containers.${idDB} = {
    containerConfig = {
      image = "docker.io/postgres:18";
      environmentFiles = [ config.sops.templates."${idDB}.env".path ];
      environments.TZ = osConfig.time.timeZone;
      networks = [ "${internalNet}" ];
      volumes = [
        "${idDB}:/var/lib/postgresql"
      ];
      healthCmd = "pg_isready -qU $POSTGRES_USER";
      healthRetries = 2;
      healthInterval = "30s";
      healthTimeout = "10s";
      healthStartPeriod = "120s";
      healthStartupInterval = "5s";
    };
  };
}
