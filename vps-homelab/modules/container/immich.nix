{
  vars,
  config,
  osConfig,
  ...
}:

let
  # Common
  subDomain = "photos";
  publicNet = "immich-net";
  internalNet = "immich-internal-net";
  versionTag = "v2";
  url = "${subDomain}.${vars.DOMAIN}";

  # Server
  server = {
    id = "immich-server";
    containerPort = "2283";
  };

  # Machine Learning
  ml = {
    id = "immich-machine-learning";
  };

  # Database
  db = {
    id = "immich-database";
    versionTag = "18-vectorchord0.5.3";
  };

  # Redis
  redis = {
    id = "immich-redis";
  };

in
{
  sops.secrets."immich_db_password" = { };
  sops.templates."${server.id}.env" = {
    content = ''
      # https://docs.immich.app/install/environment-variables/
      IMMICH_MACHINE_LEARNING_URL=http://${ml.id}:3003
      REDIS_HOSTNAME=${redis.id}
      DB_HOSTNAME=${db.id}
      DB_USERNAME=immich
      DB_DATABASE_NAME=immich

      DB_PASSWORD=${config.sops.placeholder."immich_db_password"}
    '';
  };

  sops.templates."${db.id}.env" = {
    content = ''
      POSTGRES_DB=immich
      POSTGRES_USER=immich
      POSTGRES_INITDB_ARGS='--data-checksums'

      POSTGRES_PASSWORD=${config.sops.placeholder."immich_db_password"}
    '';
  };

  # Define pangolin public-resources
  # Options: ../containers.nix
  hmOpts.pangolin.blueprints."${server.id}" = {
    name = server.id;
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
          path = "/api/server/ping";
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
  virtualisation.quadlet.networks."${internalNet}" = {
    networkConfig = {
      internal = true;
    };
  };
  virtualisation.quadlet.volumes."${server.id}" = { };
  virtualisation.quadlet.containers.${server.id} = {
    unitConfig = {
      After = [
        "${redis.id}.service"
        "${db.id}.service"
      ];
      Requires = [
        "${redis.id}.service"
        "${db.id}.service"
      ];
    };
    containerConfig = {
      image = "ghcr.io/immich-app/immich-server:${versionTag}";
      dropCapabilities = [ "ALL" ];
      addCapabilities = [ ];
      noNewPrivileges = true;
      environmentFiles = [ config.sops.templates."${server.id}.env".path ];
      environments.TZ = osConfig.time.timeZone;
      networks = [
        "${publicNet}"
        "${internalNet}"
      ];
      volumes = [
        "${server.id}:/data"
      ];
      labels = {
        "traefik.enable" = "true";
        "traefik.http.routers.${server.id}.rule" = "Host(`${url}`)";
        "traefik.http.services.${server.id}.loadbalancer.server.port" = server.containerPort;
      };
    };
  };

  virtualisation.quadlet.volumes."${ml.id}" = { };
  virtualisation.quadlet.containers.${ml.id} = {
    containerConfig = {
      image = "ghcr.io/immich-app/immich-machine-learning:${versionTag}";
      dropCapabilities = [ "ALL" ];
      addCapabilities = [ ];
      noNewPrivileges = true;
      environments.TZ = osConfig.time.timeZone;
      networks = [ "${internalNet}" ];
      volumes = [
        "${ml.id}:/cache"
      ];
    };
  };

  virtualisation.quadlet.containers.${redis.id} = {
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

  virtualisation.quadlet.volumes."${db.id}" = { };
  virtualisation.quadlet.containers.${db.id} = {
    containerConfig = {
      image = "ghcr.io/immich-app/postgres:${db.versionTag}";
      shmSize = "128mb";
      environmentFiles = [ config.sops.templates."${db.id}.env".path ];
      environments.TZ = osConfig.time.timeZone;
      networks = [ "${internalNet}" ];
      volumes = [
        "${db.id}:/var/lib/postgresql"
      ];
    };
  };
}
